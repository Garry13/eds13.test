#!/usr/bin/perl
#################################################
# Virtual machines backuping script             #
#################################################
if (system('ping -c 1 xxx.xxx.xxx.xxx>/dev/null'))
{
print "Target computer offline";
}
else {
print "Целевая машина онлайн";
system('sudo mount -t cifs //xxx.xxx.xxx.xxx/VirtualBox$ -o users,file_mode=0777,dir_mode=0777,username="DOMAIN\User",password=OurPass /mnt/mount_dir');
$debug=1;
$dstdir="/mnt/mount_dir/backup_dir";
$pidfile="/var/run/vbox_backup.pid";
$pr=0;
    
open (TMP,"<$pidfile") or newpid();
if ($pr == 0){
    $op=<TMP>;
    $cmd=sprintf ("/bin/ps -axo pid | /usr/bin/grep -w '%d' | /usr/bin/grep -v 'grep'",$op);
    do_debug($cmd);
    $op=`$cmd`;
    chomp($op);
    if ($op eq ""){
        do_debug("Override old PID");
        newpid();
    }else{
        print "VirtualBox backup can't start: process already executed";
    }
}
close TMP;
}                                                                                                                    
sub newpid {
        $pr=1;
        open (PID,">$pidfile");
        print PID $$;
        close PID;
        run();
}
                                                                                                                                        
sub run {
    $date=`/bin/date "+%Y/%m/%d"`;
    chomp($date);
    $backupdir=sprintf("%s/%s",$dstdir,$date);
    $vboxmanage="/usr/bin/VBoxManage";

    $vmslist=`$vboxmanage list runningvms | /bin/grep {`;
    chomp($vmslist);
    @vms_tmp=split('\n',$vmslist);
    for $m(@vms_tmp){
        @vms=split(' ',$m);
        $vms[0]=~s/"//g;        #"
        $vms[1]=~s/{//;
        $vms[1]=~s/}//;
        do_debug("Name: $vms[0] UID: $vms[1]");
        $cmd=`$vboxmanage showvminfo $vms[1]`;
        $vmbackupdir=sprintf("%s/%s",$backupdir,$vms[0]);
        opendir DIR,$vmbackupdir or create_dir($vmbackupdir);
        open(TXT, sprintf(">%s/readme.txt",$vmbackupdir));
        print TXT $cmd;
        close(TXT);
        $cmd="$vboxmanage -q controlvm $vms[1] savestate";
        do_debug($cmd);
        $savestate=`$cmd`;
        chomp($savestate);
        do_debug($savestate);
        if ($savestate ne "0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%"){
        print "[WARNING]: VM $vms[0] has some problem with savestate\nResult: $savestate\n";
        }

        `/bin/sleep 5`;

        $cmd=sprintf("%s -q export %s -o %s/%s.ovf",$vboxmanage,$vms[1],$vmbackupdir,$vms[0]);
        do_debug($cmd);
        $export=`$cmd`;
        chomp($export);
        @out=split("\n",$export);
        $export_res=$out[$#out];
        do_debug($export_res);
        if ($export_res ne "Successfully exported 1 machine(s)."){
            print "[WARNING]: VM $vms[0] has some problem with export\nResult: $export_res\n";
        }

        `/bin/sleep 2`;

        $cmd="$vboxmanage -q startvm $vms[1] --type headless";
        do_debug($cmd);
        $start=`$cmd`;
        @out=split("\n",$start);
        $power=$out[$#out];
        do_debug($power);
        if ($power ne "VM has been successfully started."){
            print "[WARNING]: VM $vms[0] don`t started after backuping !\nResult: $power";
        }
        do_debug("VM $vms[0] backup finished...\n");
    }
    cleanup();
    system('sudo umount -l -t cifs /mnt/mount_dir');
    unlink($pidfile);
}
                                                                                                                                
sub create_dir {
    $dir=shift;
    `/bin/mkdir -p $dir`;
}
 
sub cleanup{
    $date=`/bin/date --date="1 month ago" +%Y/%m/%d`;
    chomp($date);
    do_debug("Clean up $date");
    $cleandir=sprintf("%s/%s",$dstdir,$date);
    `/bin/rm -rf $cleandir`;
}

sub do_debug{
    $text=shift;
    if ($debug){
        print "[DEBUG]: $text\n";
    }
}