module Scratch
import Base: UUID
using Dates

export with_scratch_directory, scratch_dir, get_scratch!, delete_scratch!, clear_scratchspaces!, @get_scratch!

const SCRATCH_DIR_OVERRIDE = Ref{Union{String,Nothing}}(nothing)
"""
    with_scratch_directory(f::Function, scratch_dir::String)

Helper function to allow temporarily changing the scratch space directory.  When this is
set, no other directory will be searched for spaces, and new spaces will be created
within this directory.  Similarly, removing a scratch space will only effect the given
scratch directory.
"""
function with_scratch_directory(f::Function, scratch_dir::String)
    try
        SCRATCH_DIR_OVERRIDE[] = scratch_dir
        f()
    finally
        SCRATCH_DIR_OVERRIDE[] = nothing
    end
end

"""
    scratch_dir(args...)

Returns a path within the current depot's `scratchspaces` directory.  This location can
be overridden via `with_scratch_directory()`.
"""
function scratch_dir(args...)
    if SCRATCH_DIR_OVERRIDE[] === nothing
        return abspath(first(Base.DEPOT_PATH), "scratchspaces", args...)
    else
        # If we've been given an override, use _only_ that directory.
        return abspath(SCRATCH_DIR_OVERRIDE[], args...)
    end
end

const uuid_re = r"uuid\s*=\s*(?i)\"([0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12})\""

find_uuid(uuid::UUID) = uuid
find_uuid(mod::Module) = find_uuid(Base.PkgId(mod).uuid)
function find_uuid(::Nothing)
    # Try and see if the current project has a UUID
    project = Base.active_project()
    if project !== nothing && isfile(project)
        str = read(project, String)
        if (m = match(uuid_re, str); m !== nothing)
            return UUID(m[1])
        end
    end
    # If we still haven't found a UUID, fall back to the "global namespace"
    return UUID(UInt128(0))
end

"""
    scratch_path(pkg_uuid, key)

Common utility function to return the path of a scratch space, keyed by the given
parameters.  Users should use `get_scratch!()` for most user-facing usage.
"""
function scratch_path(pkg_uuid::UUID, key::AbstractString)
    return scratch_dir(string(pkg_uuid), key)
end

# Session-based space access time tracker
## Should perhaps keep track of find_project_file(UUID) instead
## but since you can only load a package once per Julia session,
## and since these timers are reset for every session, keeping
## track of the calling UUID should be good enough.
const scratch_access_timers = Dict{Tuple{UUID,String},Float64}()
"""
    track_scratch_access(pkg_uuid, scratch_path)

We need to keep track of who is using which spaces, so we know when it is advisable to
remove them during a GC.  We do this by attributing accesses of spaces to `Project.toml`
files in much the same way that package versions themselves are logged upon install, only
instead of having the project information implicitly available, we must rescue it out
from the currently-active Pkg Env.  If we cannot do that, it is because someone is doing
something weird like opening a space for a Pkg UUID that is not loadable, which we will
simply not track; that space will be reaped after the appropriate time in an orphanage.

If `pkg_uuid` is explicitly set to `nothing`, this space is treated as belonging to the
current project, or if that does not exist, the default global project located at
`Base.load_path_expand("@v#.#")`.

While package and artifact access tracking can be done at `add()`/`instantiate()` time,
we must do it at access time for spaces, as we have no declarative list of spaces that
a package may or may not access throughout its lifetime.  To avoid building up a
ludicrously large number of accesses through programs that e.g. call `get_scratch!()` in a
loop, we only write out usage information for each space once per day at most.
"""
function track_scratch_access(pkg_uuid::UUID, scratch_path::AbstractString)
    # Don't write this out more than once per day within the same Julia session.
    curr_time = time()
    if get(scratch_access_timers, (pkg_uuid, scratch_path), 0.0) >= curr_time - 60*60*24
        return
    end

    function find_project_file(pkg_uuid::UUID)
        # The simplest case (`pkg_uuid` == UUID(0)) simply attributes the space to
        # the active project, and if that does not exist, the  global depot environment,
        # which will never cause the space to be GC'ed because it has been removed,
        # as long as the global environment within the depot itself is intact.
        if pkg_uuid === UUID(UInt128(0))
            p = Base.active_project()
            if p !== nothing
                return p
            end
            return Base.load_path_expand("@v#.#")
        end

        # Otherwise, we attempt to find the source location of the package identified
        # by `pkg_uuid`, then find its owning `Project.toml`:
        for (p, m) in Base.loaded_modules
            if p.uuid == pkg_uuid
                source_path = Base.pathof(m)
                if source_path !== nothing
                    return Base.current_project(dirname(source_path))
                end
            end
        end

        # Finally, make one last desperate attempt and check if the
        # active project has our UUID
        if pkg_uuid === find_uuid(nothing)
            p = Base.active_project()
            if p !== nothing
                return p
            end
        end

        # If we couldn't find anything to attribute the space to, return `nothing`.
        return nothing
    end

    # We must decide which manifest to attribute this space to.
    project_file = find_project_file(pkg_uuid)

    # If we couldn't find one, skip out.
    if project_file === nothing || !ispath(project_file)
        return
    end

    # We manually format some simple TOML entries so that we don't have
    # to depend on the whole TOML writer stdlib.
    toml_entry = string(
        "[[\"", escape_string(abspath(scratch_path)), "\"]]\n",
        "time = ", string(now()), "Z\n",
        "parent_projects = [\"", escape_string(abspath(project_file)), "\"]\n",
    )
    usage_file = usage_toml()
    mkpath(dirname(usage_file))
    open(usage_file, append=true) do io
        write(io, toml_entry)
    end

    # Record that we did, in fact, write out the space access time
    scratch_access_timers[(pkg_uuid, scratch_path)] = curr_time
end

usage_toml() = joinpath(first(Base.DEPOT_PATH), "logs", "scratch_usage.toml")

# We clear the access timers from every entry referencing this path
# even if the calling package might not match. This is safer,
# since it only means that we might print out some extra entries
# to scratch_usage.toml instead of missing to record some usage.
function prune_timers!(path)
    for k in keys(scratch_access_timers)
        _, recorded_path = k
        if path == recorded_path
            delete!(scratch_access_timers, k)
        end
    end
    return nothing
end

"""
    get_scratch!(parent_pkg = nothing, key::AbstractString, calling_pkg = parent_pkg)

Returns the path to (or creates) a space.

If `parent_pkg` is given (either as a `UUID` or as a `Module`), the scratch space is
namespaced with that package's UUID, so that it will not conflict with any other space
with the same name but a different parent package UUID.  The space's lifecycle is tied
to the calling package, allowing the space to be garbage collected if all versions of the
package that used it have been removed.  By default, `parent_pkg` and `calling_pkg` are
the same, however in rare cases a package may become dependent on a scratch space that is
namespaced within another package, in such cases they should identify themselves as the
`calling_pkg` so that the scratch space's lifecycle is tied to that calling package.

If `parent_pkg` is not defined, or is a `Module` without a root UUID (e.g. `Main`,
`Base`, an anonymous module, etc...) the created scratch space is namespaced within the
global environment for the current version of Julia.

Scratch spaces are removed if all calling projects that have accessed them are removed.
As an example, if a scratch space is used by two versions of the same package but not a
newer version, when the two older versions are removed the scratch space may be garbage
collected.  See `Pkg.gc()` and `track_scratch_access()` for more details.
"""
function get_scratch!(parent_pkg::Union{Module,UUID,Nothing}, key::AbstractString,
                      calling_pkg::Union{Module,UUID,Nothing} = parent_pkg)
    # Verify that the key is valid (only needed here at construction time)
    if match(r"^[a-zA-Z0-9-\._]+$", key) === nothing
        throw(ArgumentError(
            "invalid key \"$key\": keys may only include a-z, A-Z, 0-9, -, _, and ."
            ))
    end
    parent_pkg = find_uuid(parent_pkg)
    calling_pkg = find_uuid(calling_pkg)
    # Calculate the path and create the containing folder
    path = scratch_path(parent_pkg, key)
    mkpath(path)

    # We need to keep track of who is using which spaces, so we track usage in a log
    track_scratch_access(calling_pkg, path)
    return path
end
get_scratch!(key::AbstractString) = get_scratch!(nothing, key)

"""
    delete_scratch!(parent_pkg, key)

Explicitly deletes a scratch space created through `get_scratch!()`.
"""
function delete_scratch!(parent_pkg::Union{Module,UUID,Nothing}, key::AbstractString, )
    parent_pkg = find_uuid(parent_pkg)
    path = scratch_path(parent_pkg, key)
    rm(path; force=true, recursive=true)
    prune_timers!(path)
    return nothing
end
delete_scratch!(key::AbstractString) = delete_scratch!(nothing, key)

"""
    clear_scratchspaces!()

Delete all scratch spaces in the current depot.
"""
function clear_scratchspaces!()
    rm(scratch_dir(); force=true, recursive=true)
    empty!(scratch_access_timers)
    return nothing
end

"""
    clear_scratchspaces!(parent_pkg::Union{Module,UUID})

Delete all scratch spaces for the given package.
"""
function clear_scratchspaces!(parent_pkg::Union{Module,UUID,Nothing})
    parent_pkg = find_uuid(parent_pkg)
    if parent_pkg === UUID(UInt128(0))
        # TODO: Why not make this a way to clear the global scratchspace ??
        throw(ArgumentError("Cannot find owning package for module"))
    end
    parent_prefix = scratch_dir(string(parent_pkg))
    # First prune the access timers from all references to paths belonging to this namespace
    for (_, path) in keys(scratch_access_timers)
        if startswith(path, parent_prefix)
            prune_timers!(path)
        end
    end
    # Next, remove the whole namespace
    rm(parent_prefix; force=true, recursive=true)
    return nothing
end

"""
    @get_scratch!(key)

Convenience macro that gets/creates a scratch space with the given key and parented to
the package the calling module belongs to.  If the calling module does not belong to a
package, (e.g. it is `Main`, `Base`, an anonymous module, etc...) the UUID will be taken
to be `nothing`, creating a global scratchspace.
"""
macro get_scratch!(key)
    # Note that if someone uses this in the REPL, it will return `nothing`, and thereby
    # create a global scratch space.
    uuid = Base.PkgId(__module__).uuid
    return quote
        get_scratch!($(esc(uuid)), $(esc(key)), $(esc(uuid)))
    end
end

end # module Scratch
