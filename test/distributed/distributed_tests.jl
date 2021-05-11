include(joinpath(Sys.BINDIR, "..", "share", "julia", "test", "testenv.jl"))
disttestfile = joinpath(@__DIR__, "run_dtests.jl")
push!(test_exeflags.exec,"--color=yes")
cmd = `$test_exename $test_exeflags $disttestfile`

# Do not test on windows due to memory issues
@static if !Sys.iswindows()
    @info "Starting distributed tests..."
    if !success(pipeline(cmd; stdout=stdout, stderr=stderr)) && ccall(:jl_running_on_valgrind, Cint, ()) == 0
        @error "Distributed test failed, cmd : $cmd"
    end
end
