subroutine filter_assim(ens_handle, obs_ens_handle, obs_seq, keys,           &
   ens_size, num_groups, obs_val_index, inflate, ENS_MEAN_COPY, ENS_SD_COPY, &
   ENS_INF_COPY, ENS_INF_SD_COPY, OBS_KEY_COPY, OBS_GLOBAL_QC_COPY,          &
   OBS_PRIOR_MEAN_START, OBS_PRIOR_MEAN_END, OBS_PRIOR_VAR_START,            &
   OBS_PRIOR_VAR_END, inflate_only)

(1) if (timing(MLOOP)) allocate(elapse_array(obs_ens_handle%num_vars))

! we are going to read/write the copies array
call prepare_to_update_copies(ens_handle)
call prepare_to_update_copies(obs_ens_handle)

! Initialize assim_tools_module if needed
(2) if (.not. module_initialized) call assim_tools_init()

!HK make window for mpi one-sided communication
! used for vertical conversion in get_close_obs
! Need to give create_mean_window the mean copy
call create_mean_window(ens_handle, ENS_MEAN_COPY, distribute_mean)

! filter kinds 1 and 8 return sorted increments, however non-deterministic
! inflation can scramble these. the sort is expensive, so help users get better
! performance by rejecting namelist combinations that do unneeded work.
(3) if (sort_obs_inc) then
    (4) if(deterministic_inflate(inflate) .and. ((filter_kind == 1) .or. (filter_kind == 8))) then
      write(msgstring,  *) 'With a deterministic filter [assim_tools_nml:filter_kind = ',filter_kind,']'
      write(msgstring2, *) 'and deterministic inflation [filter_nml:inf_deterministic = .TRUE.]'
      write(msgstring3, *) 'assim_tools_nml:sort_obs_inc = .TRUE. is not needed and is expensive.'
      call error_handler(E_MSG,'', '')  ! whitespace
      call error_handler(E_MSG,'WARNING filter_assim:', msgstring, source, &
                         text2=msgstring2,text3=msgstring3)
      call error_handler(E_MSG,'', '')  ! whitespace
      sort_obs_inc = .FALSE.
   endif
endif

!GSR open the dignostics file
(5) if(output_localization_diagnostics .and. my_task_id() == 0) then
  localization_unit = open_file(localization_diagnostics_file, action = 'append')
endif

! For performance, make local copies of these settings which
! are really in the inflate derived type.
local_single_ss_inflate  = do_single_ss_inflate(inflate)
local_varying_ss_inflate = do_varying_ss_inflate(inflate)
local_ss_inflate         = do_ss_inflate(inflate)
local_obs_inflate        = do_obs_inflate(inflate)

! Default to printing nothing
nth_obs = -1

! Divide ensemble into num_groups groups.
! make sure the number of groups and ensemble size result in
! at least 2 members in each group (to avoid divide by 0) and
! that the groups all have the same number of members.
grp_size = ens_size / num_groups
(6) if ((grp_size * num_groups) /= ens_size) then
   write(msgstring,  *) 'The number of ensemble members must divide into the number of groups evenly.'
   write(msgstring2, *) 'Ensemble size = ', ens_size, '  Number of groups = ', num_groups
   write(msgstring3, *) 'Change number of groups or ensemble size to avoid remainders.'
   call error_handler(E_ERR,'filter_assim:', msgstring, source, &
                         text2=msgstring2,text3=msgstring3)
endif
(7) if (grp_size < 2) then
   write(msgstring,  *) 'There must be at least 2 ensemble members in each group.'
   write(msgstring2, *) 'Ensemble size = ', ens_size, '  Number of groups = ', num_groups
   write(msgstring3, *) 'results in < 2 members/group.  Decrease number of groups or increase ensemble size'
   call error_handler(E_ERR,'filter_assim:', msgstring, source, &
                         text2=msgstring2,text3=msgstring3)
endif
(8) do group = 1, num_groups
   grp_beg(group) = (group - 1) * grp_size + 1
   grp_end(group) = grp_beg(group) + grp_size - 1
enddo

! Put initial value of state space inflation in copy normally used for SD
! This is to avoid weird storage footprint in filter
ens_handle%copies(ENS_SD_COPY, :) = ens_handle%copies(ENS_INF_COPY, :)

! For single state or obs space inflation, the inflation is like a token
! Gets passed from the processor with a given obs on to the next
(9) if(local_single_ss_inflate) then
   my_inflate    = ens_handle%copies(ENS_INF_COPY,    1)
   my_inflate_sd = ens_handle%copies(ENS_INF_SD_COPY, 1)
end if

! Get info on my number and indices for obs
my_num_obs = get_my_num_vars(obs_ens_handle)
call get_my_vars(obs_ens_handle, my_obs_indx)

! Construct an observation temporary
call init_obs(observation, get_num_copies(obs_seq), get_num_qc(obs_seq))

! Get the locations for all of my observations
! HK I would like to move this to before the calculation of the forward operator so you could
! overwrite the vertical location with the required localization vertical coordinate when you
! do the forward operator calculation
call get_my_obs_loc(obs_ens_handle, obs_seq, keys, my_obs_loc, my_obs_kind, my_obs_type, obs_time)

(10) if (convert_all_obs_verticals_first .and. is_doing_vertical_conversion) then
   ! convert the vertical of all my observations to the localization coordinate
   (11) if (timing(LG_GRN)) call start_timer(t_base(LG_GRN))
   (12)if (obs_ens_handle%my_num_vars > 0) then
      call convert_vertical_obs(ens_handle, obs_ens_handle%my_num_vars, my_obs_loc, &
                                my_obs_kind, my_obs_type, get_vertical_localization_coord(), vstatus)
      do i = 1, obs_ens_handle%my_num_vars
         if (good_dart_qc(nint(obs_ens_handle%copies(OBS_GLOBAL_QC_COPY, i)))) then
            !> @todo Can I just use the OBS_GLOBAL_QC_COPY? Is it ok to skip the loop?
            if (vstatus(i) /= 0) obs_ens_handle%copies(OBS_GLOBAL_QC_COPY, i) = DARTQC_FAILED_VERT_CONVERT
         endif
      enddo
   endif 
   (13) if (timing(LG_GRN)) call read_timer(t_base(LG_GRN), 'convert_vertical_obs')
endif

! Get info on my number and indices for state
my_num_state = get_my_num_vars(ens_handle)
call get_my_vars(ens_handle, my_state_indx)

! Get the location and kind of all my state variables
(14) if (timing(LG_GRN)) call start_timer(t_base(LG_GRN))
do i = 1, ens_handle%my_num_vars
   call get_state_meta_data(my_state_indx(i), my_state_loc(i), my_state_kind(i))
end do
(15) if (timing(LG_GRN)) call read_timer(t_base(LG_GRN), 'get_state_meta_data')

!call test_get_state_meta_data(my_state_loc, ens_handle%my_num_vars)

!> optionally convert all state location verticals
(16) if (convert_all_state_verticals_first .and. is_doing_vertical_conversion) then
   (17) if (timing(LG_GRN)) call start_timer(t_base(LG_GRN))
   (18) if (ens_handle%my_num_vars > 0) then
      call convert_vertical_state(ens_handle, ens_handle%my_num_vars, my_state_loc, my_state_kind,  &
                                  my_state_indx, get_vertical_localization_coord(), istatus)
   endif
   (19) if (timing(LG_GRN)) call read_timer(t_base(LG_GRN), 'convert_vertical_state')
endif

! PAR: MIGHT BE BETTER TO HAVE ONE PE DEDICATED TO COMPUTING
! INCREMENTS. OWNING PE WOULD SHIP IT'S PRIOR TO THIS ONE
! BEFORE EACH INCREMENT.

! Get mean and variance of each group's observation priors for adaptive inflation
! Important that these be from before any observations have been used
(20) if(local_ss_inflate) then
   do group = 1, num_groups
      obs_mean_index = OBS_PRIOR_MEAN_START + group - 1
      obs_var_index  = OBS_PRIOR_VAR_START  + group - 1
         call compute_copy_mean_var(obs_ens_handle, grp_beg(group), grp_end(group), &
           obs_mean_index, obs_var_index)
   end do
endif

! The computations in the two get_close_maxdist_init are redundant

! Initialize the method for getting state variables close to a given ob on my process
(21) if (has_special_cutoffs) then
   call get_close_init(gc_state, my_num_state, 2.0_r8*cutoff, my_state_loc, 2.0_r8*cutoff_list)
else
   call get_close_init(gc_state, my_num_state, 2.0_r8*cutoff, my_state_loc)
endif

! Initialize the method for getting obs close to a given ob on my process
(22) if (has_special_cutoffs) then
   call get_close_init(gc_obs, my_num_obs, 2.0_r8*cutoff, my_obs_loc, 2.0_r8*cutoff_list)
else
   call get_close_init(gc_obs, my_num_obs, 2.0_r8*cutoff, my_obs_loc)
endif

(23) if (close_obs_caching) then
   ! Initialize last obs and state get_close lookups, to take advantage below
   ! of sequential observations at the same location (e.g. U,V, possibly T,Q)
   ! (this is getting long enough it probably should go into a subroutine. nsc.)
   last_base_obs_loc           = set_location_missing()
   last_base_states_loc        = set_location_missing()
   last_num_close_obs          = -1
   last_num_close_states       = -1
   last_close_obs_ind(:)       = -1
   last_close_state_ind(:)     = -1
   last_close_obs_dist(:)      = 888888.0_r8   ! something big, not small
   last_close_state_dist(:)    = 888888.0_r8   ! ditto
   num_close_obs_cached        = 0
   num_close_states_cached     = 0
   num_close_obs_calls_made    = 0
   num_close_states_calls_made = 0
endif

allow_missing_in_state = get_missing_ok_status()

! use MLOOP for the overall outer loop times; LG_GRN is for
! sections inside the overall loop, including the total time
! for the state_update and obs_update loops.  use SM_GRN for
! sections inside those last 2 loops and be careful - they will
! be called nobs * nstate * ntasks.

! Loop through all the (global) observations sequentially
SEQUENTIAL_OBS: do i = 1, obs_ens_handle%num_vars

   (24) if (timing(MLOOP))  call start_timer(t_base(MLOOP))
   (25) if (timing(LG_GRN)) call start_timer(t_base(LG_GRN))

   ! Some compilers do not like mod by 0, so test first.
   (26) if (print_every_nth_obs > 0) nth_obs = mod(i, print_every_nth_obs)

   ! If requested, print out a message every Nth observation
   ! to indicate progress is being made and to allow estimates
   ! of how long the assim will take.
   (27) if (nth_obs == 0) then
      write(msgstring, '(2(A,I8))') 'Processing observation ', i, &
                                         ' of ', obs_ens_handle%num_vars
      (28) if (print_timestamps == 0) then
         call error_handler(E_MSG,'filter_assim',msgstring)
      else
         call timestamp(trim(msgstring), pos="brief")
      endif
   endif

   ! Every pe has information about the global obs sequence
   call get_obs_from_key(obs_seq, keys(i), observation)
   call get_obs_def(observation, obs_def)
   base_obs_loc = get_obs_def_location(obs_def)
   obs_err_var = get_obs_def_error_variance(obs_def)
   base_obs_type = get_obs_def_type_of_obs(obs_def)
   (29) if (base_obs_type > 0) then
      base_obs_kind = get_quantity_for_type_of_obs(base_obs_type)
   else
      call get_state_meta_data(-1 * int(base_obs_type,i8), dummyloc, base_obs_kind)  ! identity obs
   endif
   ! Get the value of the observation
   call get_obs_values(observation, obs, obs_val_index)

   ! Find out who has this observation and where it is
   call get_var_owner_index(ens_handle, int(i,i8), owner, owners_index)

   ! Following block is done only by the owner of this observation
   !-----------------------------------------------------------------------
   (30) if(ens_handle%my_pe == owner) then
      ! each task has its own subset of all obs.  if they were converted in the
      ! vertical up above, then we need to broadcast the new values to all the other
      ! tasks so they're computing the right distances when applying the increments.
      (31) if (is_doing_vertical_conversion) then
         vertvalue_obs_in_localization_coord = query_location(my_obs_loc(owners_index), "VLOC")
         whichvert_obs_in_localization_coord = query_location(my_obs_loc(owners_index), "WHICH_VERT")
      else
         vertvalue_obs_in_localization_coord = 0.0_r8
         whichvert_obs_in_localization_coord = 0
      endif

      obs_qc = obs_ens_handle%copies(OBS_GLOBAL_QC_COPY, owners_index)
      ! Only value of 0 for DART QC field should be assimilated
      (32) IF_QC_IS_OKAY: if(nint(obs_qc) ==0) then
         obs_prior = obs_ens_handle%copies(1:ens_size, owners_index)

         ! Compute the prior mean and variance for this observation
         orig_obs_prior_mean = obs_ens_handle%copies(OBS_PRIOR_MEAN_START: &
            OBS_PRIOR_MEAN_END, owners_index)
         orig_obs_prior_var  = obs_ens_handle%copies(OBS_PRIOR_VAR_START:  &
            OBS_PRIOR_VAR_END, owners_index)

         ! Compute observation space increments for each group
         do group = 1, num_groups
            grp_bot = grp_beg(group)
            grp_top = grp_end(group)
            call obs_increment(obs_prior(grp_bot:grp_top), grp_size, obs(1), &
               obs_err_var, obs_inc(grp_bot:grp_top), inflate, my_inflate,   &
               my_inflate_sd, net_a(group))
         end do

         ! Compute updated values for single state space inflation
         (33) SINGLE_SS_INFLATE: if(local_single_ss_inflate) then
            ss_inflate_base = ens_handle%copies(ENS_SD_COPY, 1)
            ! Update for each group separately
            do group = 1, num_groups
               ! If either inflation or sd is not positive, not really doing inflation
               (34) if(my_inflate > 0.0_r8 .and. my_inflate_sd > 0.0_r8) then
                  ! For case with single spatial inflation, use gamma = 1.0_r8
                  ! See adaptive inflation module for details
                  gamma = 1.0_r8
                  ! Deflate the inflated variance; required for efficient single pass
                  ! This is one of many places that assumes linear state/obs relation
                  ! over range of ensemble; Essentially, we are removing the inflation
                  ! which has already been applied in filter to see what inflation should
                  ! have been needed.
                  ens_obs_mean = orig_obs_prior_mean(group)
                  ens_obs_var = orig_obs_prior_var(group)
                  ! gamma is hardcoded as 1.0, so no test is needed here.
                  ens_var_deflate = ens_obs_var / &
                     (1.0_r8 + gamma*(sqrt(ss_inflate_base) - 1.0_r8))**2

                  ! If this is inflate_only (i.e. posterior) remove impact of this obs.
                  ! This is simulating independent observation by removing its impact.
                  (35) if(inflate_only .and. &
                        ens_var_deflate               > small .and. &
                        obs_err_var                   > small .and. &
                        obs_err_var - ens_var_deflate > small ) then
                     r_var = 1.0_r8 / (1.0_r8 / ens_var_deflate - 1.0_r8 / obs_err_var)
                     r_mean = r_var *(ens_obs_mean / ens_var_deflate - obs(1) / obs_err_var)
                  else
                     r_var = ens_var_deflate
                     r_mean = ens_obs_mean
                  endif

                  (36) if (timing(SM_GRN)) call start_timer(t_base(SM_GRN), t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)
                  ! Update the inflation value
                  call update_inflation(inflate, my_inflate, my_inflate_sd, &
                     r_mean, r_var, grp_size, obs(1), obs_err_var, gamma)
                  (37) if (timing(SM_GRN)) call read_timer(t_base(SM_GRN), 'update_inflation_C', &
                                                      t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)
               endif
            end do
         endif SINGLE_SS_INFLATE

      endif IF_QC_IS_OKAY

      !Broadcast the info from this obs to all other processes
      ! What gets broadcast depends on what kind of inflation is being done
      !>@todo it should also depend on if vertical is being converted.  the last
      !>two values aren't needed unless vertical conversion is happening.
      !>@todo FIXME: this is messy, but should we have 6 different broadcasts,
      !>the three below and three more which omit the 2 localization values?
      !>how much does this cost in time? time this and see.
      whichvert_real = real(whichvert_obs_in_localization_coord, r8)
      (38) if(local_varying_ss_inflate) then
         call broadcast_send(map_pe_to_task(ens_handle, owner), obs_prior, obs_inc, &
            orig_obs_prior_mean, orig_obs_prior_var, net_a, scalar1=obs_qc, &
            scalar2=vertvalue_obs_in_localization_coord, scalar3=whichvert_real)

      (39) else if(local_single_ss_inflate .or. local_obs_inflate) then
         call broadcast_send(map_pe_to_task(ens_handle, owner), obs_prior, obs_inc, &
           net_a, scalar1=my_inflate, scalar2=my_inflate_sd, scalar3=obs_qc, &
           scalar4=vertvalue_obs_in_localization_coord, scalar5=whichvert_real)
      else
         call broadcast_send(map_pe_to_task(ens_handle, owner), obs_prior, obs_inc, &
           net_a, scalar1=obs_qc, &
           scalar2=vertvalue_obs_in_localization_coord, scalar3=whichvert_real)
      endif

   ! Next block is done by processes that do NOT own this observation
   !-----------------------------------------------------------------------
   else
      ! I don't store this obs; receive the obs prior and increment from broadcast
      ! Also get qc and inflation information if needed
      ! also a converted vertical coordinate if needed
      !>@todo FIXME see the comment in the broadcast_send() section about
      !>the cost of sending unneeded values
      (40) if(local_varying_ss_inflate) then
         call broadcast_recv(map_pe_to_task(ens_handle, owner), obs_prior, obs_inc, &
            orig_obs_prior_mean, orig_obs_prior_var, net_a, scalar1=obs_qc, &
            scalar2=vertvalue_obs_in_localization_coord, scalar3=whichvert_real)
      (41) else if(local_single_ss_inflate .or. local_obs_inflate) then
         call broadcast_recv(map_pe_to_task(ens_handle, owner), obs_prior, obs_inc, &
            net_a, scalar1=my_inflate, scalar2=my_inflate_sd, scalar3=obs_qc, &
            scalar4=vertvalue_obs_in_localization_coord, scalar5=whichvert_real)
      else
         call broadcast_recv(map_pe_to_task(ens_handle, owner), obs_prior, obs_inc, &
           net_a, scalar1=obs_qc, &
           scalar2=vertvalue_obs_in_localization_coord, scalar3=whichvert_real)
      endif
      whichvert_obs_in_localization_coord = nint(whichvert_real)

   endif
   !-----------------------------------------------------------------------

   ! Everybody is doing this section, cycle if qc is bad
   (42) if(nint(obs_qc) /= 0) then
      (43) if (timing(MLOOP)) then
         write(msgstring, '(A32,I7)') 'sequential obs cycl: obs', keys(i)
         call read_timer(t_base(MLOOP), msgstring, elapsed = elapse_array(i))
      endif
      cycle SEQUENTIAL_OBS
   endif

   !> all tasks must set the converted vertical values into the 'base' version of this loc
   !> because that's what we pass into the get_close_xxx() routines below.
   (44) if (is_doing_vertical_conversion) &
      call set_vertical(base_obs_loc, vertvalue_obs_in_localization_coord, whichvert_obs_in_localization_coord)
   
   ! Can compute prior mean and variance of obs for each group just once here
   do group = 1, num_groups
      grp_bot = grp_beg(group)
      grp_top = grp_end(group)
      obs_prior_mean(group) = sum(obs_prior(grp_bot:grp_top)) / grp_size
      obs_prior_var(group) = sum((obs_prior(grp_bot:grp_top) - obs_prior_mean(group))**2) / &
         (grp_size - 1)
      (45) if (obs_prior_var(group) < 0.0_r8) obs_prior_var(group) = 0.0_r8
   end do

   ! If we are doing adaptive localization then we need to know the number of
   ! other observations that are within the localization radius.  We may need
   ! to shrink it, and so we need to know this before doing get_close() for the
   ! state space (even though the state space increments will be computed and
   ! applied first).

   !******************************************


   (46) if (.not. close_obs_caching) then
      (47) if (timing(GC)) call start_timer(t_base(GC), t_items(GC), t_limit(GC), do_sync=.false.)
      call get_close_obs(gc_obs, base_obs_loc, base_obs_type, &
                         my_obs_loc, my_obs_kind, my_obs_type, &
                         num_close_obs, close_obs_ind, close_obs_dist, ens_handle)
      (48) if (timing(GC)) then
         write(msgstring, '(A32,3I7)') 'gc_ob_NC:nobs,tot,obs# ', num_close_obs, obs_ens_handle%my_num_vars, keys(i)
         call read_timer(t_base(GC), msgstring, t_items(GC), t_limit(GC), do_sync=.false.)
      endif

   else

      (49) if (base_obs_loc == last_base_obs_loc) then
         num_close_obs     = last_num_close_obs
         close_obs_ind(:)  = last_close_obs_ind(:)
         close_obs_dist(:) = last_close_obs_dist(:)
         num_close_obs_cached = num_close_obs_cached + 1
      else
         (50) if (timing(GC)) call start_timer(t_base(GC), t_items(GC), t_limit(GC), do_sync=.false.)
         call get_close_obs(gc_obs, base_obs_loc, base_obs_type, &
                            my_obs_loc, my_obs_kind, my_obs_type, &
                            num_close_obs, close_obs_ind, close_obs_dist, ens_handle)
         (51) if (timing(GC)) then
            write(msgstring, '(A32,3I7)') 'gc_ob_C: nobs,tot,obs# ', num_close_obs, obs_ens_handle%my_num_vars, keys(i)
            call read_timer(t_base(GC), msgstring, t_items(GC), t_limit(GC), do_sync=.false.)
         endif

         last_base_obs_loc      = base_obs_loc
         last_num_close_obs     = num_close_obs
         last_close_obs_ind(:)  = close_obs_ind(:)
         last_close_obs_dist(:) = close_obs_dist(:)
         num_close_obs_calls_made = num_close_obs_calls_made +1
      endif
   endif

   n_close_obs_items(i) = num_close_obs
    !print*, 'base_obs _oc', base_obs_loc, 'rank ', my_task_id()
    !call test_close_obs_dist(close_obs_dist, num_close_obs, i)
    !print*, 'num close ', num_close_obs

   ! set the cutoff default, keep a copy of the original value, and avoid
   ! looking up the cutoff in a list if the incoming obs is an identity ob
   ! (and therefore has a negative kind).  specific types can never be 0;
   ! generic kinds (not used here) start their numbering at 0 instead of 1.
   (52) if (base_obs_type > 0) then
      cutoff_orig = cutoff_list(base_obs_type)
   else
      cutoff_orig = cutoff
   endif

   cutoff_rev = cutoff_orig

   ! For adaptive localization, need number of other obs close to the chosen observation
   (53) if(adaptive_localization_threshold > 0) then

      (54) if (timing(GC)) call start_timer(t_base(GC), t_items(GC), t_limit(GC), do_sync=.false.)

      ! this does a cross-task sum, so all tasks must make this call.
      total_num_close_obs = count_close(num_close_obs, close_obs_ind, my_obs_type, &
                                        close_obs_dist, cutoff_rev*2.0_r8)
      (55) if (timing(GC)) call read_timer(t_base(GC), 'count_close', t_items(GC), t_limit(GC), do_sync=.false.)


      ! Want expected number of close observations to be reduced to some threshold;
      ! accomplish this by cutting the size of the cutoff distance.
      (56) if(total_num_close_obs > adaptive_localization_threshold) then

         cutoff_rev = revised_distance(cutoff_rev*2.0_r8, adaptive_localization_threshold, &
                                       total_num_close_obs, base_obs_loc, &
                                       adaptive_cutoff_floor*2.0_r8) / 2.0_r8

         (57) if ( output_localization_diagnostics ) then

            ! to really know how many obs are left now, you have to
            ! loop over all the obs, again, count how many kinds are
            ! going to be assim, and explicitly check the distance and
            ! see if it's closer than the new cutoff ( times 2 ), and
            ! then do a global sum to get the total.  since this costs,
            ! do it only when diagnostics are requested.

            ! this does a cross-task sum, so all tasks must make this call.
            rev_num_close_obs = count_close(num_close_obs, close_obs_ind, my_obs_type, &
                                              close_obs_dist, cutoff_rev*2.0_r8)


            ! GSR output the new cutoff
            ! Here is what we might want:
            ! time, ob index #, ob location, new cutoff, the assimilate obs count, owner (which process has this ob)
            ! obs_time, obs_val_index, base_obs_loc, cutoff_rev, total_num_close_obs, owner
            ! break up the time into secs and days, and break up the location into lat, lon and height
            ! nsc - the min info here that can't be extracted from the obs key is:
            !  key (obs#), total_num_close_obs (close w/ original cutoff), revised cutoff & new count
            (58) if (my_task_id() == 0) then
               call get_obs_def(observation, obs_def)
               this_obs_time = get_obs_def_time(obs_def)
               call get_time(this_obs_time,secs,days)
               call write_location(-1, base_obs_loc, charstring=base_loc_text)

               write(localization_unit,'(i12,1x,i5,1x,i8,1x,A,2(f14.5,1x,i12))') i, secs, days, &
                     trim(base_loc_text), cutoff_orig, total_num_close_obs, cutoff_rev, rev_num_close_obs
            endif
         endif

      endif

   (59) else if (output_localization_diagnostics) then

      ! if you aren't adapting but you still want to know how many obs are within the
      ! localization radius, set the diag output.  this could be large, use carefully.

      ! this does a cross-task sum, so all tasks must make this call.
      total_num_close_obs = count_close(num_close_obs, close_obs_ind, my_obs_type, &
                                        close_obs_dist, cutoff_rev*2.0_r8)

      (60) if (my_task_id() == 0) then
         call get_obs_def(observation, obs_def)
         this_obs_time = get_obs_def_time(obs_def)
         call get_time(this_obs_time,secs,days)
         call write_location(-1, base_obs_loc, charstring=base_loc_text)

         write(localization_unit,'(i12,1x,i5,1x,i8,1x,A,f14.5,1x,i12)') i, secs, days, &
               trim(base_loc_text), cutoff_rev, total_num_close_obs
      endif
   endif

   ! Now everybody updates their close states
   ! Find state variables on my process that are close to observation being assimilated
   (61) if (.not. close_obs_caching) then
      (62) if (timing(GC)) call start_timer(t_base(GC), t_items(GC), t_limit(GC), do_sync=.false.)
      call get_close_state(gc_state, base_obs_loc, base_obs_type, &
                           my_state_loc, my_state_kind, my_state_indx, &
                           num_close_states, close_state_ind, close_state_dist, ens_handle)
      (63) if (timing(GC)) then
         write(msgstring, '(A32,3I7)') 'gc_st_NC:nsts,tot,obs# ', num_close_states, ens_handle%my_num_vars, keys(i)
         call read_timer(t_base(GC), msgstring, t_items(GC), t_limit(GC), do_sync=.false.)
      endif
   else
      (64) if (base_obs_loc == last_base_states_loc) then
         num_close_states    = last_num_close_states
         close_state_ind(:)  = last_close_state_ind(:)
         close_state_dist(:) = last_close_state_dist(:)
         num_close_states_cached = num_close_states_cached + 1
      else
         (65) if (timing(GC)) call start_timer(t_base(GC), t_items(GC), t_limit(GC), do_sync=.false.)
         call get_close_state(gc_state, base_obs_loc, base_obs_type, &
                              my_state_loc, my_state_kind, my_state_indx, &
                              num_close_states, close_state_ind, close_state_dist, ens_handle)
         (66) if (timing(GC)) then
            write(msgstring, '(A32,3I7)') 'gc_st_C: nsts,tot,obs# ', num_close_states, ens_handle%my_num_vars, keys(i)
            call read_timer(t_base(GC), msgstring, t_items(GC), t_limit(GC), do_sync=.false.)
         endif

         last_base_states_loc     = base_obs_loc
         last_num_close_states    = num_close_states
         last_close_state_ind(:)  = close_state_ind(:)
         last_close_state_dist(:) = close_state_dist(:)
         num_close_states_calls_made = num_close_states_calls_made + 1
      endif
   endif

   n_close_state_items(i) = num_close_states
   !print*, 'num close state', num_close_states
   !call test_close_obs_dist(close_state_dist, num_close_states, i)
   !call test_state_copies(ens_handle, 'beforeupdates')

   (67) if (timing(LG_GRN)) then
      write(msgstring, '(A32,I7)') 'before_state_update: obs', keys(i)
      call read_timer(t_base(LG_GRN), msgstring)
   endif

   ! Loop through to update each of my state variables that is potentially close
   (68) if (timing(LG_GRN)) call start_timer(t_base(LG_GRN))
   STATE_UPDATE: do j = 1, num_close_states
      state_index = close_state_ind(j)

      ! the "any" is an expensive test when you do it for every ob.  don't test
      ! if we know there aren't going to be missing values in the state.
      (69) if ( allow_missing_in_state ) then
         ! Some models can take evasive action if one or more of the ensembles have
         ! a missing value. Generally means 'do nothing' (as opposed to DIE)
         (70) if (any(ens_handle%copies(1:ens_size, state_index) == MISSING_R8)) cycle STATE_UPDATE
      endif

      ! Get the initial values of inflation for this variable if state varying inflation
      (71) if(local_varying_ss_inflate) then
         varying_ss_inflate    = ens_handle%copies(ENS_INF_COPY,    state_index)
         varying_ss_inflate_sd = ens_handle%copies(ENS_INF_SD_COPY, state_index)
      else
         varying_ss_inflate    = 0.0_r8
         varying_ss_inflate_sd = 0.0_r8
      endif

      ! Compute the distance and covariance factor
      cov_factor = comp_cov_factor(close_state_dist(j), cutoff_rev, &
         base_obs_loc, base_obs_type, my_state_loc(state_index), my_state_kind(state_index))

      ! if external impact factors supplied, factor them in here
      ! FIXME: this would execute faster for 0.0 impact factors if
      ! we check for that before calling comp_cov_factor.  but it makes
      ! the logic more complicated - this is simpler if we do it after.
      (72) if (adjust_obs_impact) then
         impact_factor = obs_impact_table(base_obs_type, my_state_kind(state_index))
         cov_factor = cov_factor * impact_factor
      endif

      ! If no weight is indicated, no more to do with this state variable
      if(cov_factor <= 0.0_r8) cycle STATE_UPDATE

      if (timing(SM_GRN)) call start_timer(t_base(SM_GRN), t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)
      ! Loop through groups to update the state variable ensemble members
      do group = 1, num_groups
         grp_bot = grp_beg(group)
         grp_top = grp_end(group)
         ! Do update of state, correl only needed for varying ss inflate
         (73) if(local_varying_ss_inflate .and. varying_ss_inflate > 0.0_r8 .and. &
            varying_ss_inflate_sd > 0.0_r8) then
            call update_from_obs_inc(obs_prior(grp_bot:grp_top), obs_prior_mean(group), &
               obs_prior_var(group), obs_inc(grp_bot:grp_top), &
               ens_handle%copies(grp_bot:grp_top, state_index), grp_size, &
               increment(grp_bot:grp_top), reg_coef(group), net_a(group), correl(group))
         else
            call update_from_obs_inc(obs_prior(grp_bot:grp_top), obs_prior_mean(group), &
               obs_prior_var(group), obs_inc(grp_bot:grp_top), &
               ens_handle%copies(grp_bot:grp_top, state_index), grp_size, &
               increment(grp_bot:grp_top), reg_coef(group), net_a(group))
         endif
      end do
      (74) if (timing(SM_GRN)) call read_timer(t_base(SM_GRN), 'update_from_obs_inc_S', &
                                          t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)

      ! Compute an information factor for impact of this observation on this state
      (75) if(num_groups == 1) then
          reg_factor = 1.0_r8
      else
         ! Pass the time along with the index for possible diagnostic output
         ! Compute regression factor for this obs-state pair
         reg_factor = comp_reg_factor(num_groups, reg_coef, obs_time, i, my_state_indx(state_index))
      endif

      ! The final factor is the minimum of group regression factor and localization cov_factor
      reg_factor = min(reg_factor, cov_factor)

!PAR NEED TO TURN STUFF OFF MORE EFFICEINTLY
      ! If doing full assimilation, update the state variable ensemble with weighted increments
      if(.not. inflate_only) then
         ens_handle%copies(1:ens_size, state_index) = &
            ens_handle%copies(1:ens_size, state_index) + reg_factor * increment
      endif

      ! Compute spatially-varying state space inflation
      (76) if(local_varying_ss_inflate) then
         ! base is the initial inflate value for this state variable
         ss_inflate_base = ens_handle%copies(ENS_SD_COPY, state_index)
         ! Loop through each group to update inflation estimate
         GroupInflate: do group = 1, num_groups
            (77) if(varying_ss_inflate > 0.0_r8 .and. varying_ss_inflate_sd > 0.0_r8) then
               ! Gamma is less than 1 for varying ss, see adaptive inflate module
               gamma = reg_factor * abs(correl(group))
               ! Deflate the inflated variance using the INITIAL state inflate
               ! value (before these obs started gumming it up).
               ens_obs_mean = orig_obs_prior_mean(group)
               ens_obs_var =  orig_obs_prior_var(group)

               ! Remove the impact of inflation to allow efficient single pass with assim.
               (78) if ( abs(gamma) > small ) then
                  ens_var_deflate = ens_obs_var / &
                     (1.0_r8 + gamma*(sqrt(ss_inflate_base) - 1.0_r8))**2
               else
                  ens_var_deflate = ens_obs_var
               endif

               ! If this is inflate only (i.e. posterior) remove impact of this obs.
               (79) if(inflate_only .and. &
                     ens_var_deflate               > small .and. &
                     obs_err_var                   > small .and. &
                     obs_err_var - ens_var_deflate > small ) then
                  r_var  = 1.0_r8 / (1.0_r8 / ens_var_deflate - 1.0_r8 / obs_err_var)
                  r_mean = r_var *(ens_obs_mean / ens_var_deflate - obs(1) / obs_err_var)
               else
                  r_var = ens_var_deflate
                  r_mean = ens_obs_mean
               endif

               ! IS A TABLE LOOKUP POSSIBLE TO ACCELERATE THIS?
               ! Update the inflation values
               (80) if (timing(SM_GRN)) call start_timer(t_base(SM_GRN), t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)
               call update_inflation(inflate, varying_ss_inflate, varying_ss_inflate_sd, &
                  r_mean, r_var, grp_size, obs(1), obs_err_var, gamma)
               (81) if (timing(SM_GRN)) call read_timer(t_base(SM_GRN), 'update_inflation_V', &
                                                   t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)
            else
               ! if we don't go into the previous if block, make sure these
               ! have good values going out for the block below
               r_mean = orig_obs_prior_mean(group)
               r_var =  orig_obs_prior_var(group)
            endif

            ! Update adaptive values if posterior outlier_ratio test doesn't fail.
            ! Match code in obs_space_diags() in filter.f90
            do_adapt_inf_update = .true.
            (82) if (inflate_only) then
               diff_sd = sqrt(obs_err_var + r_var)
               (83) if (diff_sd > 0.0_r8) then
                  outlier_ratio = abs(obs(1) - r_mean) / diff_sd
                  do_adapt_inf_update = (outlier_ratio <= 3.0_r8)
               endif
            endif
            (84) if (do_adapt_inf_update) then
               ens_handle%copies(ENS_INF_COPY, state_index) = varying_ss_inflate
               ens_handle%copies(ENS_INF_SD_COPY, state_index) = varying_ss_inflate_sd
            endif
         end do GroupInflate
      endif

   end do STATE_UPDATE
   (85) if (timing(LG_GRN)) then
      write(msgstring, '(A32,I7)') 'state_update: obs', keys(i)
      call read_timer(t_base(LG_GRN), msgstring)
   endif

   !call test_state_copies(ens_handle, 'after_state_updates')

   !------------------------------------------------------

   ! Now everybody updates their obs priors (only ones after this one)
   (86) if (timing(LG_GRN)) call start_timer(t_base(LG_GRN))
   OBS_UPDATE: do j = 1, num_close_obs
      obs_index = close_obs_ind(j)

      ! Only have to update obs that have not yet been used
      (87) if(my_obs_indx(obs_index) > i) then

         ! If the forward observation operator failed, no need to
         ! update the unassimilated observations
         (88) if (any(obs_ens_handle%copies(1:ens_size, obs_index) == MISSING_R8)) cycle OBS_UPDATE

         ! Compute the distance and the covar_factor
         cov_factor = comp_cov_factor(close_obs_dist(j), cutoff_rev, &
            base_obs_loc, base_obs_type, my_obs_loc(obs_index), my_obs_kind(obs_index))

         ! if external impact factors supplied, factor them in here
         ! FIXME: this would execute faster for 0.0 impact factors if
         ! we check for that before calling comp_cov_factor.  but it makes
         ! the logic more complicated - this is simpler if we do it after.
         (89) if (adjust_obs_impact) then
            impact_factor = obs_impact_table(base_obs_type, my_obs_kind(obs_index))
            cov_factor = cov_factor * impact_factor
         endif

         (90) if(cov_factor <= 0.0_r8) cycle OBS_UPDATE

         if (timing(SM_GRN)) call start_timer(t_base(SM_GRN), t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)
         ! Loop through and update ensemble members in each group
         do group = 1, num_groups
            grp_bot = grp_beg(group)
            grp_top = grp_end(group)
            call update_from_obs_inc(obs_prior(grp_bot:grp_top), obs_prior_mean(group), &
               obs_prior_var(group), obs_inc(grp_bot:grp_top), &
                obs_ens_handle%copies(grp_bot:grp_top, obs_index), grp_size, &
                increment(grp_bot:grp_top), reg_coef(group), net_a(group))
         end do
         (91) if (timing(SM_GRN)) call read_timer(t_base(SM_GRN), 'update_from_obs_inc_O', &
                                             t_items(SM_GRN), t_limit(SM_GRN), do_sync=.false.)

         ! FIXME: could we move the if test for inflate only to here?

         ! Compute an information factor for impact of this observation on this state
         (92) if(num_groups == 1) then
             reg_factor = 1.0_r8
         else
            ! Pass the time along with the index for possible diagnostic output
            ! Compute regression factor for this obs-state pair
            ! Negative indicates that this is an observation index
            reg_factor = comp_reg_factor(num_groups, reg_coef, obs_time, i, -1*my_obs_indx(obs_index))
         endif

         ! Final weight is min of group and localization factors
         reg_factor = min(reg_factor, cov_factor)

         ! Only update state if indicated (otherwise just getting inflation)
         (93) if(.not. inflate_only) then
            obs_ens_handle%copies(1:ens_size, obs_index) = &
              obs_ens_handle%copies(1:ens_size, obs_index) + reg_factor * increment
         endif
      endif
   end do OBS_UPDATE
   (94) if (timing(LG_GRN)) then
      write(msgstring, '(A32,I7)') 'obs_update: obs', keys(i)
      call read_timer(t_base(LG_GRN), msgstring)
   endif

   !call test_state_copies(ens_handle, 'after_obs_updates')

   (95) if (timing(MLOOP)) then
      write(msgstring, '(A32,I7)') 'sequential obs loop: obs', keys(i)
      call read_timer(t_base(MLOOP), msgstring, elapsed = elapse_array(i))
   endif
end do SEQUENTIAL_OBS

! Every pe needs to get the current my_inflate and my_inflate_sd back
(96) if(local_single_ss_inflate) then
   ens_handle%copies(ENS_INF_COPY, :) = my_inflate
   ens_handle%copies(ENS_INF_SD_COPY, :) = my_inflate_sd
end if

! Free up the storage
call destroy_obs(observation)
call get_close_destroy(gc_state)
call get_close_destroy(gc_obs)

! print some stats about the assimilation
! (if interesting, could print exactly which obs # was fastest and slowest)
(97) if (my_task_id() == 0 .and. timing(MLOOP)) then
   write(msgstring, *) 'average assim time: ', sum(elapse_array) / size(elapse_array)
   call error_handler(E_MSG,'filter_assim:',msgstring)

   write(msgstring, *) 'minimum assim time: ', minval(elapse_array)
   call error_handler(E_MSG,'filter_assim:',msgstring)

   write(msgstring, *) 'maximum assim time: ', maxval(elapse_array)
   call error_handler(E_MSG,'filter_assim:',msgstring)
endif

(98) if (timing(MLOOP)) deallocate(elapse_array)

! do some stats - being aware that unless we do a reduce() operation
! this is going to be per-task.  so only print if something interesting
! shows up in the stats?  maybe it would be worth a reduce() call here?

!>@todo FIXME:  
!  we have n_close_obs_items and n_close_state_items for each assimilated
!  observation.  what we really want to know is across the tasks is there
!  a big difference in counts?  so that means communication.  maybe just
!  the largest value?  and the number of 0 values?  and if the largest val
!  is way off compared to the other tasks, warn the user?
!  we don't have space or time to do all the obs * tasks but could we
!  send enough info to make a histogram?  compute N bin counts and then
!  reduce that across all the tasks and have task 0 print out?
! still thinking on this idea.
!   write(msgstring, *) 'max state items per observation: ', maxval(n_close_state_items)
!   call error_handler(E_MSG, 'filter_assim:', msgstring)
! if i come up with something i like, can we use the same idea
! for the threed_sphere locations boxes?

! Assure user we have done something
(100) if (print_trace_details >= 0) then
write(msgstring, '(A,I8,A)') &
   'Processed', obs_ens_handle%num_vars, ' total observations'
   call error_handler(E_MSG,'filter_assim:',msgstring)
endif

! diagnostics for stats on saving calls by remembering obs at the same location.
! change .true. to .false. in the line below to remove the output completely.
(101) if (close_obs_caching) then
   (102) if (num_close_obs_cached > 0 .and. do_output()) then
      print *, "Total number of calls made    to get_close_obs for obs/states:    ", &
                num_close_obs_calls_made + num_close_states_calls_made
      print *, "Total number of calls avoided to get_close_obs for obs/states:    ", &
                num_close_obs_cached + num_close_states_cached
      (103) if (num_close_obs_cached+num_close_obs_calls_made+ &
          num_close_states_cached+num_close_states_calls_made > 0) then
         print *, "Percent saved: ", 100.0_r8 * &
                   (real(num_close_obs_cached+num_close_states_cached, r8) /  &
                   (num_close_obs_calls_made+num_close_obs_cached +           &
                    num_close_states_calls_made+num_close_states_cached))
      endif
   endif
endif

!call test_state_copies(ens_handle, 'end')

!GSR close the localization diagnostics file
(104) if(output_localization_diagnostics .and. my_task_id() == 0) then
  call close_file(localization_unit)
end if

! get rid of mpi window
call free_mean_window()

end subroutine filter_assim
