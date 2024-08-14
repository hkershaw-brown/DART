module cheesecake_filter_mod
implicit none

contains

subroutine hello_world()
implicit none

#ifdef HELLO
    print *, "Hello, World!"
#else
    print *, "Goodbye!"
#endif

end subroutine hello_world


end module cheesecake_filter_mod
