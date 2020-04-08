# InfoBlox-Snippets
Most of these script are one time use highly case specifiek. But might give some inspiration.

##### Invoke-check-infobloxdomains
Create a list of all domains configured in infoblox.
The TLD of each domain in noted and checked for:\
HTTP 200-Ok with and without www in from of the domainname.
Results are written to CSV.

##### Invoke-Update-HostIP
Replaces the IP adress in a hostrecord on Infoblox.\
When migrating to a different hosting profider we had to change the IP-adress of 60+ hostrecords. We could not find a way in the webinterface to accomplish this task.

##### Invoke-Add-IPv6Addr
Slitly modified version of Update-HostIP. Adds an IPv6 adress to a existing host that has only IPv4 adresses. 
When implementing IPv6 we had to add the IPv6 record to 60+ hostrecords. We could not find a way in the webinterface to accomplish this task.

##### Invoke-ReduceDHCPScope and Invoke-Find-fixedIP
When migrating our network we had to reduces all the DHCP ranges to make room for gateways. We had fixed IP's in the new ranges and we couldn't mass reduce the configured ranges.\
Invoke-Find-fixedIP = Looks for overlapping IP's.\
Invoked-ReduceDHCPScope = reduces the configured scope.
