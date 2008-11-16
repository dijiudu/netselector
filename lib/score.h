#ifndef __LIB_SCORE_H__
#define __LIB_SCORE_H__

enum {
	SCORE_TARGET_DEFAULT = 100,
	SCORE_VLAN = 50,
	SCORE_REVARP = 10,
	SCORE_UNKNOWN = 0,
	SCORE_LLC_UNKNOWN = 0,
	SCORE_ETH_UNKNOWN = 0,
	SCORE_ARP = 5,
	SCORE_ARP_UNKNOWN = 0,
	SCORE_EAP = 100,
	SCORE_DHCPC = 5,
	SCORE_DHCPS = 100,
	SCORE_SSDP = 5,
	SCORE_GATEWAY = 50,
	SCORE_DNSS = 25,
	SCORE_DNSC = 0,
	SCORE_UDP_UNKNOWN = 0,
	SCORE_TCP = 0,
	SCORE_UDP = 0,
	SCORE_ICMP = 5,
	SCORE_IP_UNKNOWN = 0,
	SCORE_NBNS = 25,
	SCORE_WLCCP = 50,
	SCORE_SNAP_UNKNOWN = 0,
	SCORE_CDP_UNKNOWN = 25,
	SCORE_CDP = 50,
	SCORE_STP = 50,
	SCORE_STP_NONCONFIG = 10,
	SCORE_STP_UNKNOWN = 5,
	SCORE_ETHER = 5,
	SCORE_IP = 10,
};

#endif