# Ansible

## Why Ansible
Currently Ansible is the selected provisioning tool in order to learn more about it.

## Privilege escalation
- Ansible could be run directly as root and configure all other users
    * Would simplify the setup
    * sshd: disable root login after provisioning --> how could ansible run a playbook twice?
- Currently Ansible is run as the user from the installation, which has sudo privileges.
- use `--ask-become-pass` when running the playbook, this way the password has not to be put into vault.

### Advantages
- Lean installation
    * Python package
    * no agent on target machine necessary

### Disadvantage
- Procedural in nature
    * Order of tasks is important
    * Configuration drift is possible and likely
    * Some tasks need to be tweaked in order to make them idempotent
    * There are some exceptions to the above mentioned points: e.g. the apt or user module basically represent descriptive 'tasks'. It doesn't make a difference where the task is run (at least for the module itself), and the user doesn't need to describe what the task has to do, only what state the task has to reach.

### Useful references
- [Ansible special variables](https://docs.ansible.com/ansible/latest/reference_appendices/special_variables.html)
- [Ansible vault how-to](https://www.digitalocean.com/community/tutorials/how-to-use-vault-to-protect-sensitive-ansible-data)

## Notes
- Use `export ANSIBLE_HOST_KEY_CHECKING=False` to suppress the interactive prompt regarding host verification. It is not necessary for initial provisioning, only later.
- repeatedly provisioning the system might require to clear the `known_hosts` file:
    ```sh
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "192.168.122.124"
    ```
- [webpage explaining (un)commenting lines](https://www.shellhacks.com/ansible-comment-out-uncomment-lines-in-a-file/)
- ansible_facts['os_family'] is 'Debian' for both Debian and Ubuntu. ansible_facts['distribution'] is more specific.
