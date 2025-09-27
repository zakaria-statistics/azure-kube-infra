# main log (code paths, module actions)
sudo tail -f /var/log/cloud-init.log

# user-data output (what your #cloud-config/runcmd printed)
sudo tail -f /var/log/cloud-init-output.log

# current boot only; live stream (-f)
sudo journalctl -u cloud-init-local  -b -f
sudo journalctl -u cloud-init        -b -f
sudo journalctl -u cloud-config      -b -f
sudo journalctl -u cloud-final       -b -f


cloud-init status --long        # expanded status
cloud-init status --long -w     # wait until finished (not a live log, but handy)


sudo tee /etc/sudoers.d/10-ansible-path >/dev/null <<'EOF'
Defaults secure_path="/opt/ansible/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF


exec $SHELL -l                 # reloads login environment (no reboot)
source /etc/profile.d/ansible.sh
source ~/.bashrc
source ~/.profile