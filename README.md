plcemu
======
PLC comunication emulator


Requirement
======
* Ruby 1.9.3 or later


MITSUBISHI
======

Q (QJ71E71-*)
-------
Run with the binary protocol
```
$ cd mitsubishi/q
$ ./q.rb
```

FX (FX3U ENET)
-------
Run with the binary protocol
```
$ cd mitsubishi/fx
$ ./fxbin.rb
```

The ascii version is not implemented now.

AnS (AJ71E71)
-------
Run with the binary protocol
```
$ cd mitsubishi/ans
$ ./ansbin.rb
```

Run with the ascii protocol
```
$ cd mitsubishi/ans
$ ./ansascii.rb
```

OMRON
======

FINS Ethernet
-------
Run with the FINS protocol
```
$ cd omron/fins
$ ./fins.rb
```

