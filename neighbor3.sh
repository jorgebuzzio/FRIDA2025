#!/bin/bash

ip neigh add 10.0.1.2 lladdr 08:00:00:00:00:02 dev eth0
ip neigh add 10.0.1.1 lladdr 08:00:00:00:00:01 dev eth0
