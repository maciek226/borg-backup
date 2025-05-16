# borg-backup
A docker based solution to securely backing up nas/servers through Wireguard 

## Instructions 
### Prerequisite  
#### SSH Key
Create an SSH key pair 

```bash
sh-keygen -t rsa -b 4096 -C "my@email.com"
```
and place the output in an accessible location 

#### Backup preparations 
- Identify exclude paths 
- Identify include paths 
