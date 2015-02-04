require 'spec_helper'

describe 'Ubuntu 14.04 stemcell', stemcell_image: true do
  context 'installed by image_install_grub', exclude_on_warden: true do
    describe file('/boot/grub/grub.conf') do
      it { should be_file }
      it { should contain 'default=0' }
      it { should contain 'timeout=1' }
      its(:content) { should match %r{^title Ubuntu 14\.04.* LTS \(.*\)$} }
      it { should contain '  root (hd0,0)' }
      its(:content) { should match %r{kernel /boot/vmlinuz-\S+-generic ro root=UUID=} }
      it { should contain ' selinux=0' }
      it { should contain ' cgroup_enable=memory swapaccount=1' }
      it { should contain ' console=tty0 console=ttyS0,115200n8' }
      its(:content) { should match %r{initrd /boot/initrd.img-\S+-generic} }
    end

    describe file('/boot/grub/menu.lst') do
      before { skip 'until aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.conf') }
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('ubuntu') }
    end
  end

  context 'installed by bosh_harden' do
    describe 'disallow unsafe setuid binaries' do
      subject { backend.run_command('find -L / -xdev -perm +6000 -a -type f')[:stdout].split }

      it { should match_array(%w(/bin/su /usr/bin/sudo /usr/bin/sudoedit)) }
    end

    describe 'disallow root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PermitRootLogin no$/ }
    end
  end

  context 'installed by system-aws-network', {
    exclude_on_vsphere: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
  } do
    describe file('/etc/network/interfaces') do
      it { should be_file }
      it { should contain 'auto eth0' }
      it { should contain 'iface eth0 inet dhcp' }
    end
  end

  context 'installed by system_open_vm_tools', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
  } do
    describe package('open-vm-tools') do
      it { should be_installed }
    end
  end

  context 'installed by image_vsphere_cdrom stage', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
  } do
    describe file('/etc/udev/rules.d/60-cdrom_id.rules') do
      it { should be_file }
      its(:content) { should eql(<<HERE) }
# Generated by BOSH stemcell builder

ACTION=="remove", GOTO="cdrom_end"
SUBSYSTEM!="block", GOTO="cdrom_end"
KERNEL!="sr[0-9]*|xvd*", GOTO="cdrom_end"
ENV{DEVTYPE}!="disk", GOTO="cdrom_end"

# unconditionally tag device as CDROM
KERNEL=="sr[0-9]*", ENV{ID_CDROM}="1"

# media eject button pressed
ENV{DISK_EJECT_REQUEST}=="?*", RUN+="cdrom_id --eject-media $devnode", GOTO="cdrom_end"

# Do not lock CDROM drive when cdrom is inserted
# because vSphere will start asking questions via API.
# IMPORT{program}="cdrom_id --lock-media $devnode"
IMPORT{program}="cdrom_id $devnode"

KERNEL=="sr0", SYMLINK+="cdrom", OPTIONS+="link_priority=-100"

LABEL="cdrom_end"
HERE
    end
  end

  context 'installed by bosh_openstack_agent_settings', {
    exclude_on_aws: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"CreatePartitionIfNoEphemeralDisk": true') }
      it { should contain('"UseConfigDrive": true') }
    end
  end
end
