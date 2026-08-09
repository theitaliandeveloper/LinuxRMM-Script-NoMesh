# Tactical RMM Agent Unofficial installer (No MeshCentral Edition)
Script for one-line installation and updating of the Tactical RMM agent withoyut MeshCentral Agent.

We dont provide technical support for this. If you need help, check the Tactical RMM community first!

> Scripts are now available for x64, x86, arm64, and armv6. However, only x64 and i386 have been tested on Debian 11 and Debian 10 on bare metal, VMs (Proxmox), and VPS (OVH).
> Tested on raspberry 2B+ with armv7l (chose armv6 on install)

Scripts for other platforms will be available later as we adapt the script to other platforms.
Feel free to adapt the script and submit changes that will contribute!

# Usage

### Tips

Download script with this url: `https://raw.githubusercontent.com/theitaliandeveloper/LinuxRMM-Script-NoMesh/main/rmmagent-linux.sh`

For Ubuntu systems try: `wget https://raw.githubusercontent.com/theitaliandeveloper/LinuxRMM-Script-NoMesh/main/rmmagent-linux.sh`
Make executable after downloading with: `sudo chmod +x rmmagent-linux.sh` 


## Automatically Detect System Architecture  

The system architecture is now detected automatically using the following logic:  

1. The `uname -m` command retrieves the current system's architecture.  
2. A `case` statement then checks the architecture and maps it to a standard format:  
   - `x86_64` → `amd64` (for 64-bit Intel/AMD processors)  
   - `i386` or `i686` → `x86` (for older 32-bit Intel processors)  
   - `aarch64` → `arm64` (for 64-bit ARM processors, like Raspberry Pi 4 and Apple M1/M2 chips)  
   - `armv6l` → `armv6` (for older ARM devices, like Raspberry Pi Zero)  
3. If the architecture isn't recognized, an error message is displayed, and the script exits to prevent issues.  

This ensures the script adapts to different system types automatically without needing manual input.


## Install
To install the agent, launch the script with this argument:

```bash
./rmmagent-linux.sh install 'API URL' 'Client ID' 'Site ID' 'Auth Key' 'Agent Type'
```
The compiling can be quite long, don't panic and wait few minutes... USE THE 'SINGLE QUOTES' IN ALL FIELDS!

The arguments are:

  
1. API URL

  Your api URL for agent communication usually https://api.example.com.
  
2. Client ID

  The ID of the client in wich agent will be added.
  Can be viewed by hovering over the name of the client in the dashboard.
  
3. Site ID

  The ID of the site in wich agent will be added.
  Can be viewed by hovering over the name of the site in the dashboard.
  
4. Auth Key

  Authentification key given by dashboard by going to dashboard > Agents > Install agent (Windows) > Select manual and show
  Copy **ONLY** the key after *--auth*.
  
5. Agent Type

  Can be *server* or *workstation* and define the type of agent.
  
### Example
```bash
./rmmagent-linux.sh install 'https://api.example.com' 3 1 'XXXXX' server
```

## Update

Simply launch the script with *update* as argument.

```bash
./rmmagent-linux.sh update
```

## Uninstall
To uninstall the agent, launch the script with this argument:

```bash
./rmmagent-linux.sh uninstall
```

### WARNING
- You should **only** attempt this if the agent removal feature on TacticalRMM is not working.
- Running uninstall will **not** remove the connections from the TacticalRMM and MeshCentral Dashboard. You will need to manually remove them. It only forcefully removes the agents from your linux box.

## Credits
Thanks to all contributors of the [original project](https://github.com/netvolt/LinuxRMM-Script)!

This scripts is licensed with MIT license from the original author:

Copyright (c) 2022 ZoLuSs