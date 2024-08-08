fs = import ('fs')

python = import('python').find_installation()
python_dependency = python.dependency()

compiler_arguments = []
linker_arguments = ['-static']

omp_dependency = dependency('openmp', required: false)
if not omp_dependency.found()
    if host_machine.system() == 'darwin'
        brew = find_program('brew', required : false)
        if brew.found()
            output = run_command(brew, 'list', 'libomp', check: true)
            output = output.stdout().strip()
            if output.contains('/libomp/')
                message('Found "libomp"!')
                omp_root = fs.parent(output.split('\n')[0])
                omp_dependency = declare_dependency(
                    compile_args : ['-Xpreprocessor', '-fopenmp'],
                    link_args : ['-L' + omp_root + '/lib', '-fopenmp'],
                    include_directories : include_directories(omp_root / 'include')
                )
            endif
        endif
    endif
    if host_machine.system() == 'linux'
        compiler_arguments = ['-fopenmp']
        linker_arguments = ['-fopenmp']
    endif
endif

numpy_include_directory = run_command(python,
    ['-c', 'import os; os.chdir(".."); import numpy; print(numpy.get_include())'],
    check: true
).stdout().strip()

numpy_dependency = declare_dependency(include_directories: include_directories(numpy_include_directory))

module = python.extension_module(
    'chromatic_aberration_correction',
    'chromatic_aberration_correction.pyx',
    cpp_args: compiler_arguments,
    link_args: linker_arguments,
    dependencies : [python_dependency, numpy_dependency, omp_dependency],
    install: true,
)
