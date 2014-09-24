relaiproxy.rb
==============

An extranet server want to send command (http/soap) to a intranet http-server. 
this intranet server (equipments/soap) are many and vairables.

So realiproxy.rb define 2 process :
* intranet side: **relai** :  maintain pool of sockets open with the proxy (initiated by a http request) 
* extranet-side: **relaiproxy** : receive soap request and send them to relai via  pool sockets


Schema
======

```
                                                                        h[XX]=[ip,80,/]
request--------http://proxy_hostname:prox-port/XX-------------------------------->>>> http://ip:80/
      <--------------------------------------------------------------------------response
      
                        =================      firewal     =========
Server ---------------> |  proxy-relai  | <------//--------| relai | ------------>>>> hosts
                        =================                  =========
         proxy-hostname                 proxy-ip                            ( config h[borne]= [ip,port,path] )
             proxy-port                 proxy-port
\___________________________________________/          \_______________/           .............
           internet server                              server-in-intranet         intranet hosts
```


Usage
=====
Extranet:
    >  ruby relaiproxy.rb  proxyhttp  proxy-hostname proxy-port

Intranet:
    > vi relai_config.rb
    >  ruby relaiproxy.rb  relai      proxy-ip  proxy-port  plugin-name

(actualy ocpp is the plugin)

