# Assets
- the bare-metal folders (`lat7490`, `qemu`, `nuc8i7beh`) hold files and configurations specific for the corresponding asset (e.g. storage, network, custom commands).

## server ssh keys
For server installations:
- add the user's public ssh key to ADDITIONAL_FILES and refer to it in `vars.env`
- Handle the copying of the key into the authorized_keys in the custom-commands.
- For Ansible specify the key to use (`ansible_ssh_private_key_file`) in group-/host-vars 
