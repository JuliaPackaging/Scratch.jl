var documenterSearchIndex = {"docs":
[{"location":"#Scratch.jl-Documentation","page":"Scratch.jl Documentation","title":"Scratch.jl Documentation","text":"","category":"section"},{"location":"","page":"Scratch.jl Documentation","title":"Scratch.jl Documentation","text":"This is the reference documentation of Scratch.jl.","category":"page"},{"location":"#Index","page":"Scratch.jl Documentation","title":"Index","text":"","category":"section"},{"location":"","page":"Scratch.jl Documentation","title":"Scratch.jl Documentation","text":"","category":"page"},{"location":"#Macros","page":"Scratch.jl Documentation","title":"Macros","text":"","category":"section"},{"location":"","page":"Scratch.jl Documentation","title":"Scratch.jl Documentation","text":"Modules = [Scratch]\nOrder = [:macro]","category":"page"},{"location":"#Scratch.@get_scratch!-Tuple{Any}","page":"Scratch.jl Documentation","title":"Scratch.@get_scratch!","text":"@get_scratch!(key)\n\nConvenience macro that gets/creates a scratch space with the given key and parented to the package the calling module belongs to.  If the calling module does not belong to a package, (e.g. it is Main, Base, an anonymous module, etc...) the UUID will be taken to be nothing, creating a global scratchspace.\n\n\n\n\n\n","category":"macro"},{"location":"#Functions","page":"Scratch.jl Documentation","title":"Functions","text":"","category":"section"},{"location":"","page":"Scratch.jl Documentation","title":"Scratch.jl Documentation","text":"Modules = [Scratch]\nOrder = [:function]","category":"page"},{"location":"#Scratch.clear_scratchspaces!-Tuple{Union{Nothing, Base.UUID, Module}}","page":"Scratch.jl Documentation","title":"Scratch.clear_scratchspaces!","text":"clear_scratchspaces!(parent_pkg::Union{Module,UUID})\n\nDelete all scratch spaces for the given package.\n\n\n\n\n\n","category":"method"},{"location":"#Scratch.clear_scratchspaces!-Tuple{}","page":"Scratch.jl Documentation","title":"Scratch.clear_scratchspaces!","text":"clear_scratchspaces!()\n\nDelete all scratch spaces in the current depot.\n\n\n\n\n\n","category":"method"},{"location":"#Scratch.delete_scratch!-Tuple{Union{Nothing, Base.UUID, Module}, AbstractString}","page":"Scratch.jl Documentation","title":"Scratch.delete_scratch!","text":"delete_scratch!(parent_pkg, key)\n\nExplicitly deletes a scratch space created through get_scratch!().\n\n\n\n\n\n","category":"method"},{"location":"#Scratch.get_scratch!","page":"Scratch.jl Documentation","title":"Scratch.get_scratch!","text":"get_scratch!(parent_pkg = nothing, key::AbstractString, calling_pkg = parent_pkg)\n\nReturns the path to (or creates) a space.\n\nIf parent_pkg is given (either as a UUID or as a Module), the scratch space is namespaced with that package's UUID, so that it will not conflict with any other space with the same name but a different parent package UUID.  The space's lifecycle is tied to the calling package, allowing the space to be garbage collected if all versions of the package that used it have been removed.  By default, parent_pkg and calling_pkg are the same, however in rare cases a package may become dependent on a scratch space that is namespaced within another package, in such cases they should identify themselves as the calling_pkg so that the scratch space's lifecycle is tied to that calling package.\n\nIf parent_pkg is not defined, or is a Module without a root UUID (e.g. Main, Base, an anonymous module, etc...) the created scratch space is namespaced within the global environment for the current version of Julia.\n\nScratch spaces are removed if all calling projects that have accessed them are removed. As an example, if a scratch space is used by two versions of the same package but not a newer version, when the two older versions are removed the scratch space may be garbage collected.  See Pkg.gc() and track_scratch_access() for more details.\n\n\n\n\n\n","category":"function"},{"location":"#Scratch.scratch_dir-Tuple","page":"Scratch.jl Documentation","title":"Scratch.scratch_dir","text":"scratch_dir(args...)\n\nReturns a path within the current depot's scratchspaces directory.  This location can be overridden via with_scratch_directory().\n\n\n\n\n\n","category":"method"},{"location":"#Scratch.scratch_path-Tuple{Base.UUID, AbstractString}","page":"Scratch.jl Documentation","title":"Scratch.scratch_path","text":"scratch_path(pkg_uuid, key)\n\nCommon utility function to return the path of a scratch space, keyed by the given parameters.  Users should use get_scratch!() for most user-facing usage.\n\n\n\n\n\n","category":"method"},{"location":"#Scratch.track_scratch_access-Tuple{Base.UUID, AbstractString}","page":"Scratch.jl Documentation","title":"Scratch.track_scratch_access","text":"track_scratch_access(pkg_uuid, scratch_path)\n\nWe need to keep track of who is using which spaces, so we know when it is advisable to remove them during a GC.  We do this by attributing accesses of spaces to Project.toml files in much the same way that package versions themselves are logged upon install, only instead of having the project information implicitly available, we must rescue it out from the currently-active Pkg Env.  If we cannot do that, it is because someone is doing something weird like opening a space for a Pkg UUID that is not loadable, which we will simply not track; that space will be reaped after the appropriate time in an orphanage.\n\nIf pkg_uuid is explicitly set to nothing, this space is treated as belonging to the current project, or if that does not exist, the default global project located at Base.load_path_expand(\"@v#.#\").\n\nWhile package and artifact access tracking can be done at add()/instantiate() time, we must do it at access time for spaces, as we have no declarative list of spaces that a package may or may not access throughout its lifetime.  To avoid building up a ludicrously large number of accesses through programs that e.g. call get_scratch!() in a loop, we only write out usage information for each space once per day at most.\n\n\n\n\n\n","category":"method"},{"location":"#Scratch.with_scratch_directory-Tuple{Function, String}","page":"Scratch.jl Documentation","title":"Scratch.with_scratch_directory","text":"with_scratch_directory(f::Function, scratch_dir::String)\n\nHelper function to allow temporarily changing the scratch space directory.  When this is set, no other directory will be searched for spaces, and new spaces will be created within this directory.  Similarly, removing a scratch space will only effect the given scratch directory.\n\n\n\n\n\n","category":"method"}]
}
