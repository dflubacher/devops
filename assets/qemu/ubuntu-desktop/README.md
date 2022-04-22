# Qemu Ubuntu Desktop
Emulating Lat7490 setup.

## Ansible
- copy Ansible related content to `${HOME}/setup`
  * /usr/local/share/ansible
  * /usr/local/share/pyproject.toml
- set up venv: `cd ${HOME}/setup && poetry update`
- Run Ansible:
  `poetry run ansible-playbook --ask-become-pass -i ansible/staging --limit "qemu_lat7490"` ansible/desktop.yml