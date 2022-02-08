check this    DONE
-rw-r--r-- 1 raeder p86850054 16699 Feb 28  2020 DART_config.template
-rwxr-xr-x 1 raeder p86850054 16932 Feb 28  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/DART_config

update  DONE
-rw-r--r-- 1 raeder p86850054 44768 Feb 27  2020 assimilate.csh.template
-rwxr-xr-x 1 raeder p86850054 47944 Sep  9 09:01 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/assimilate.csh

update  DONE
-rwxr-xr-x 1 raeder p86850054 8331 Feb 21  2020 compress.csh
-rwxr-xr-x 1 raeder p86850054 8637 May  9  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/compress.csh

update; No, it doesn't belong in shell_scripts because it is created by setup_advanced
        >>>git rm it    DONE
-rw-r--r-- 1 raeder p86850054 1704 Feb 21  2020 data_scripts.csh
-rwxr-xr-x 1 raeder p86850054 2506 Mar 10  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/data_scripts.csh

update  DONE
-rwxr-xr-x 1 raeder p86850054 4557 Feb 22  2020 diags_rean.csh
-rwxr-xr-x 1 raeder p86850054 4789 Jul 12 20:34 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/diags_rean.csh

identical
-rwxr-xr-x 1 raeder p86850054 845 Feb 28  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/launch_cf.sh
-rwxr-xr-x 1 raeder p86850054 845 Feb 15  2020 launch_cf.sh

identical
-rwxr-xr-x 1 raeder p86850054 4097 Feb 28  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/matlab_norm.csh
-rwxr-xr-x 1 raeder p86850054 4097 Feb 15  2020 matlab_norm.csh

update; copy it over   DONE
-rwxr-xr-x 1 raeder p86850054 6964 Jun 16  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/mv_to_campaign.csh
-rwxr-xr-x 1 raeder p86850054 6858 Feb 26  2020 mv_to_campaign.csh

don't update, maybe add
-rwxr-xr-x 1 raeder p86850054 2808 Jul  9  2019 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/no_assimilate.csh
-rw-r--r-- 1 raeder p86850054 2571 Feb 14  2020 no_assimilate.csh.template

copy over   DONE
-rwxr-xr-x 1 raeder p86850054 1988 Jun  1  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/pre_purge_check.csh
-rwxr-xr-x 1 raeder p86850054 1846 Feb 22  2020 pre_purge_check.csh

copy over   DONE
-rwxr-xr-x 1 raeder p86850054 8777 Aug 27 16:45 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/pre_submit.csh
-rwxr-xr-x 1 raeder p86850054 6579 Feb 22  2020 pre_submit.csh

copy over   DONE
-rwxr-xr-x 1 raeder p86850054 10307 Mar 21  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/purge.csh
-rwxr-xr-x 1 raeder p86850054  7084 Feb 26  2020 purge.csh

update  DONE
-rwxr-xr-x 1 raeder p86850054 10480 Nov 11 20:08 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/repack_project.csh
-rwxr-xr-x 1 raeder p86850054  9677 Feb 26  2020 repack_project.csh

update  DONE
-rwxr-xr-x 1 raeder p86850054 37692 Sep  3 07:57 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/repack_st_arch.csh
-rwxr-xr-x 1 raeder p86850054 35947 Feb 26  2020 repack_st_arch.csh

update?   DONE
   in shell_scripts:
      fix raeder@ucar.edu in a copy of setup_advanced  (and other things that should be YOUR placeholders)
      'restart set exists' should continue to use .i. instead of .r.(Rean)?
ls: cannot access /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/setup_advanced: No such file or directory
-rwxr-xr-x 1 raeder p86850054 65710 Feb 29  2020 setup_advanced
-rwxr-xr-x 1 raeder p86850054 69457 Feb  7  2020 setup_advanced_Rean_2017
-rwxr-xr-x 1 raeder p86850054 63109 Oct 10  2019 setup_advanced_Test4

update  DONE
-rwxr-xr-x 1 raeder p86850054 1925 Jul  5 10:27 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/submit_compress.csh
-rw-r--r-- 1 raeder p86850054 1143 Feb 22  2020 submit_compress.csh

update  DONE
        Why lower case 'your_'... in $CASEROOT?
        That's because of 2 stage setup involving DART_config,
        Setup{_advanced} only modifies DART_config.template, which must then modify 
        lots of scripts to give them info like $caseroot, which is set in setup.
        So DART_config.template has both YOUR_CASEROOT and your_caseroot.
        Setup replaces that your_caseroot with $caseroot.
        Then the resulting DART_config looks into lots of scripts and replaces 
        their YOUR_CASEROOTs with the $caseroot value it has inherited.
-rwxr-xr-x 1 raeder p86850054 2096 Jun  1  2020 /glade/work/raeder/Exp/f.e21.FHIST_BGC.f09_025.CAM6assim.011/submit_compress_hist.csh
-rw-r--r-- 1 raeder p86850054 2075 Feb 22  2020 submit_compress_hist.csh

