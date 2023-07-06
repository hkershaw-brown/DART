from subprocess import check_output, CalledProcessError
def dart_dir():
    """ return the top level directory of DART """
    try:
        dart = check_output(['git', 'rev-parse', '--show-toplevel'])
    except CalledProcessError:
        raise IOError('Current working directory is not a git repository')
    return dart.decode('utf-8').strip()

