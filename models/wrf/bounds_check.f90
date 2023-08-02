function boundsCheck ( ind, periodic, id, dim, type )

  integer,  intent(in)  :: ind ! i or j index
  logical,  intent(in)  :: periodic ! whether the domain is periodic
      ! for longitude x periodic_x=T/F
      ! for latitude  y polar=T/F
  integer,  intent(in)  :: id ! domain id
  integer,  intent(in)  :: dim ! dimension 1,2,3 x,y,z
  integer,  intent(in)  :: type ! variable type - this is for the staggering
      ! replace with a function, takes type returns stagger

  logical :: boundsCheck  
  logical, parameter :: restrict_polar = .false.

  ! Consider cases in REAL-VALUED indexing:
  !
  ! I. Longitude -- x-direction
  !    A. PERIODIC (period_x = .true.)
  !
  !       Consider Mass-grid (& V-grid) longitude grid with 4 west-east gridpoints
  !         Values  ::  [ -135 -45  45 135 ] .. {225}
  !         Indices ::  [   1   2   3   4  ] .. {1,5}
  !       Complementary U-grid
  !         Values  ::  [ -180 -90  0  90  180 ]
  !         Indices ::  [   1   2   3   4   5  ]
  !
  !       What are the allowable values for a real-valued index on each of these grids?
  !       1. M-grid  --->  [1 5)       ---> [1 we+1)
  !                  --->  [-135 225)  
  !       2. U-grid  --->  [1 5)       ---> [1 wes)
  !                  --->  [-180 180)
  !       [Note that above "allowable values" reflect that one should be able to have
  !        an observation anywhere on a given longitude circle -- the information 
  !        exists in order to successfully interpolate to anywhere over [0 360).]
  !
  !       It is up to the routine calling "boundsCheck" to have handled the 0.5 offset
  !         in indices between the M-grid & U-grid.  Hence, two examples: 
  !          a. If there is an observation location at -165 longitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 4.667
  !             * An observation of TYPE_U (on the U-grid) would have ind = 1.167
  !          b. If there is an observation location at 0 longitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 2.5
  !             * An observation of TYPE_U (on the U-grid) would have ind = 3.0
  !
  !    B. NOT periodic (period_x = .false.)
  !
  !       Consider Mass-grid (& V-grid) longitude grid with 4 west-east gridpoints
  !         Values  ::  [  95  105 115 125 ] 
  !         Indices ::  [   1   2   3   4  ] 
  !       Complementary U-grid
  !         Values  ::  [  90  100 110 120 130 ]
  !         Indices ::  [   1   2   3   4   5  ]
  !
  !       What are the allowable values for a real-valued index on each of these grids?
  !       1. M-grid  --->  [1 4]       ---> [1 we]
  !                  --->  [95 125]  
  !       2. U-grid  --->  [1.5 4.5]       ---> [1.5 we+0.5]
  !                  --->  [95 125]
  !       [Note that above "allowable values" reflect that one should only be able to
  !        have an observation within the M-grid, since that is the only way to  
  !        guarantee that the necessary information exists in order to successfully 
  !        interpolate to a specified location.]
  !
  !       It is up to the routine calling "boundsCheck" to have handled the 0.5 offset
  !         in indices between the M-grid & U-grid.  Hence, two examples: 
  !          a. If there is an observation location at 96 longitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 1.1
  !             * An observation of TYPE_U (on the U-grid) would have ind = 1.6
  !          b. If there is an observation location at 124 longitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 3.9
  !             * An observation of TYPE_U (on the U-grid) would have ind = 4.4
  !
  ! II. Latitude -- y-direction
  !    A. PERIODIC (polar = .true.)
  !
  !       Consider Mass-grid (& U-Grid) latitude grid with 4 south-north gridpoints
  !         Values  :: [ -67.5 -22.5  22.5  67.5 ] 
  !         Indices :: [   1     2     3     4   ] 
  !       Complementary V-grid 
  !         Values  :: [ -90   -45     0    45    90 ] 
  !         Indices :: [   1     2     3     4     5 ] 
  !
  !       What are the allowable values for a real-valued index on each of these grids?
  !       1. M-grid  --->  [0.5 4.5]   ---> [0.5 sn+0.5]
  !                  --->  [-90 90]  
  !       2. U-grid  --->  [1 5]       ---> [1 sns]
  !                  --->  [-90 90]
  !       [Note that above "allowable values" reflect that one should be able to have
  !        an observation anywhere along a give latitude circle -- the information 
  !        exists in order to successfully interpolate to anywhere over [-90 90]; 
  !        however, in latitude this poses a special challenge since the seams join
  !        two separate columns of data over the pole, as opposed to in longitude
  !        where the seam wraps back on a single row of data.]  
  !
  !       It is up to the routine calling "boundsCheck" to have handled the 0.5 offset
  !         in indices between the M-grid & V-grid.  Hence, two examples: 
  !          a. If there is an observation location at -75 latitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 0.833
  !             * An observation of TYPE_V (on the V-grid) would have ind = 1.333
  !          b. If there is an observation location at 0 latitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 2.5
  !             * An observation of TYPE_V (on the V-grid) would have ind = 3.0
  !
  !    B. NOT periodic (polar = .false.)
  !
  !       Consider Mass-grid (& U-Grid) latitude grid with 4 south-north gridpoints
  !         Values  :: [ 10  20  30  40 ] 
  !         Indices :: [  1   2   3   4 ] 
  !       Complementary V-grid 
  !         Values  :: [  5  15  25  35  45 ] 
  !         Indices :: [  1   2   3   4   5 ] 
  !
  !       What are the allowable values for a real-valued index on each of these grids?
  !       1. M-grid  --->  [1 4]   ---> [1 sn]
  !                  --->  [10 40]  
  !       2. U-grid  --->  [1.5 4.5]       ---> [1.5 sn+0.5]
  !                  --->  [10 40]
  !       [Note that above "allowable values" reflect that one should only be able to
  !        have an observation within the M-grid, since that is the only way to  
  !        guarantee that the necessary information exists in order to successfully 
  !        interpolate to a specified location.]
  !
  !       It is up to the routine calling "boundsCheck" to have handled the 0.5 offset
  !         in indices between the M-grid & V-grid.  Hence, two examples: 
  !          a. If there is an observation location at 11 latitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 1.1
  !             * An observation of TYPE_V (on the V-grid) would have ind = 1.6
  !          b. If there is an observation location at 25 latitude, then:
  !             * An observation of TYPE_T (on the M-grid) would have ind = 2.5
  !             * An observation of TYPE_V (on the V-grid) would have ind = 3.0
  ! 
  ! III. Vertical -- z-direction (periodicity not an issue)
  !    
  !    Consider Mass vertical grid with 4 bottom-top gridpoints
  !      Values  :: [ 0.875 0.625 0.375 0.125 ]
  !      Indices :: [   1     2     3     4   ]
  !    Complementary W-grid
  !      Values  :: [   1   0.75  0.50  0.25    0   ]
  !      Indices :: [   1     2     3     4     5   ]
  !
  !    What are the allowable values for a real-valued index on each of these grids?
  !    1. M-grid  --->  [1 4]           ---> [1 bt]
  !               --->  [0.875 0.125]  
  !    2. W-grid  --->  [1.5 4.5]       ---> [1.5 bt+0.5]
  !               --->  [0.875 0.125]
  !
  !    [Note that above "allowable values" reflect that one should only be able to
  !     have an observation within the M-grid, since that is the only way to  
  !     guarantee that the necessary information exists in order to successfully 
  !     interpolate to a specified location.]
  !

  ! Summary of Allowable REAL-VALUED Index Values ==> INTEGER Index Values 
  !
  ! In longitude (x) direction
  !   Periodic     & M_grid ==> [1 we+1)       ==> [1 wes)
  !   Periodic     & U_grid ==> [1 wes)        ==> [1 wes)
  !   NOT Periodic & M_grid ==> [1 we]         ==> [1 we)
  !   NOT Periodic & U_grid ==> [1.5 we+0.5]   ==> [1 wes)
  ! In latitude (y) direction
  !   Periodic     & M_grid ==> [0.5 sn+0.5]   ==> [0 sns) *though in practice, [1 sn)*
  !   Periodic     & V_grid ==> [1 sns]        ==> [1 sns) *though allowable range, [1.5 sn+.5]*
  !   NOT Periodic & M_grid ==> [1 sn]         ==> [1 sn)
  !   NOT Periodic & V_grid ==> [1.5 sn+0.5]   ==> [1 sns)
  ! In vertical (z) direction
  !                  M_grid ==> [1 bt]         ==> [1 bt)
  !                  W_grid ==> [1.5 bt+0.5]   ==> [1 bts)
  

  ! Assume boundsCheck is false unless we can prove otherwise
  boundsCheck = .false.

  ! First check direction (dimension)
  !   Longitude (x-direction) has dim == 1
  if ( dim == 1 ) then

     ! Next check periodicity
     if ( periodic ) then
        
        ! If periodic in longitude, then no need to check staggering because both
        !   M and U grids allow integer indices from [1 wes)
        if ( ind >= 1 .and. ind < wrf%dom(id)%wes ) boundsCheck = .true.

     else

        ! If NOT periodic in longitude, then we need to check staggering because
        !   M and U grids allow different index ranges

        ! Check staggering by comparing var_size(dim,type) to the staggered dimension 
        !   for dim == 1 stored in wrf%dom(id)
        if ( wrf%dom(id)%var_size(dim,type) == wrf%dom(id)%wes ) then
           ! U-grid allows integer range of [1 wes)
           if ( ind >= 1 .and. ind < wrf%dom(id)%wes ) boundsCheck = .true.
        else  
           ! M & V-grid allow [1 we)
           if ( ind >= 1 .and. ind < wrf%dom(id)%we ) boundsCheck = .true.
        endif

     endif

   !   Latitude (y-direction) has dim == 2
   elseif ( dim == 2 ) then

     ! Next check periodicity
     if ( periodic ) then
        
        ! We need to check staggering because M and V grids allow different indices

!*** NOTE: For now are disallowing observation locations that occur poleward of the 
!            first and last M-grid gridpoints.  This means that this function will 
!            return false for polar observations.  This need not be the case because
!            the information should be available for proper interpolation across the
!            poles, but it will require more clever thinking.  Hopefully this can 
!            be added in later.  

        ! Check staggering by comparing var_size(dim,type) to the staggered dimension 
        !   for dim == 2 stored in wrf%dom(id)
        if ( wrf%dom(id)%var_size(dim,type) == wrf%dom(id)%sns ) then
           ! V-grid allows integer range [1 sns)
           if ( ind >= 1 .and. ind < wrf%dom(id)%sns ) boundsCheck = .true.
        else  
           ! For now we will set a logical flag to more restrictively check the array
           !   bounds under our no-polar-obs assumptions
           if ( restrict_polar ) then
              ! M & U-grid allow integer range [1 sn) in practice (though properly, [0 sns) )
              if ( ind >= 1 .and. ind < wrf%dom(id)%sn ) boundsCheck = .true.
           else
              ! M & U-grid allow integer range [0 sns) in unrestricted circumstances
              if ( ind >= 0 .and. ind < wrf%dom(id)%sns ) boundsCheck = .true.
           endif
        endif
        
     else

        ! We need to check staggering because M and V grids allow different indices
        if ( wrf%dom(id)%var_size(dim,type) == wrf%dom(id)%sns ) then
           ! V-grid allows [1 sns)
           if ( ind >= 1 .and. ind < wrf%dom(id)%sns ) boundsCheck = .true.
        else 
           ! M & U-grid allow [1 sn)
           if ( ind >= 1 .and. ind < wrf%dom(id)%sn ) boundsCheck = .true.
        endif

     endif

  elseif ( dim == 3 ) then

     ! No periodicity to worry about in the vertical!  However, we still need to check
     !   staggering because the ZNU and ZNW grids allow different index ranges
! HK what is the relationship between bt
     if ( wrf%dom(id)%var_size(dim,type) == wrf%dom(id)%bts ) then
        ! W vertical grid allows [1 bts)
        if ( ind >= 1 .and. ind < wrf%dom(id)%bts ) boundsCheck = .true.
     else
        ! M vertical grid allows [1 bt)
        if ( ind >= 1 .and. ind < wrf%dom(id)%bt ) boundsCheck = .true.
     endif
  
  else

     print*, 'model_mod.f90 :: function boundsCheck :: dim must equal 1, 2, or 3!'

  endif


end function boundsCheck
