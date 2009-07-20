#include <stddef.h>
#include <string.h>
#include "wpa_ctrl.h"
#include "netsummoner.h"
#include "execute.h"
#include "wpa.h"

#define MSG_LEN	1024

struct wpa_ctrl *wpa_ctl;
static bool wpa_connected;

struct module_info module_wpa;

static int wpa_get_id(const char *list, const char *ssid) {
	char *line;
	line = strstr(list, ssid);
	if(!line) {
		return -1;
	}
	while(*(--line) != '\n')
		;
	line++;
	return atoi(line);
}

static int wpa_callback(struct network *net) {
	int ret;

	ret = wpa_message();
	if(ret == 4) { //Disconnected
		printf("WPA DISCONNECT - EXEC DOWN\n");
		execute(net, EXEC_DOWN);
		return 1;
	}
	return 0;
}


int wpa_init(const char *iface) {
	char ctrl_path[100] = "/var/run/wpa_supplicant/";

	strcat(ctrl_path, iface);
	wpa_ctl = wpa_ctrl_open(ctrl_path);
	if(!wpa_ctl) {
		return -1;
	}
	if(wpa_ctrl_attach(wpa_ctl)) {
		return -2;
	}
	module_wpa.fnc = (dispatch_callback) wpa_callback;
	module_wpa.arg = NULL;
	module_wpa.fd = wpa_ctrl_get_fd(wpa_ctl); 
	module_wpa.timeout = -2;
	return module_wpa.fd;
}

int wpa_connect(const char *ssid, struct network *net) {
	int ret, nid;
	size_t len = MSG_LEN - 1;
	char msg[MSG_LEN];

	ret = wpa_ctrl_request(wpa_ctl, "LIST_NETWORKS", 13, msg, &len, NULL);
	msg[len - 1] = '\0';
	nid = wpa_get_id(msg, ssid);
	if(nid < 0) {
		printf("MSG: %s\n SSID: %s\n", msg, ssid);
		return 1;
	}

	wpa_connected = true;
	wpa_disconnect();

	ret = sprintf(msg, "SELECT_NETWORK %d", nid);
	len = MSG_LEN - 1;
	ret = wpa_ctrl_request(wpa_ctl, msg, ret, msg, &len, NULL);
	msg[len - 1] = '\0';
	if(strcmp("OK", msg)) {
		printf("request returned %d and %s\n", ret, msg);
		return 2;
	}
	len = MSG_LEN - 1;
	ret = wpa_ctrl_request(wpa_ctl, "RECONNECT", 9, msg, &len, NULL);
	msg[len - 1] = '\0';
	if(strcmp("OK", msg)) {
		printf("request returned %d and %s\n", ret, msg);
		return 2;
	}
	module_wpa.arg = net;
	printf("Network %s selected\n", ssid);
	return 0;
}

int wpa_disconnect(void) {
	char msg[] = "DISCONNECT";
	int ret;
	size_t len = MSG_LEN - 1;

	if(wpa_connected) {
		ret = wpa_ctrl_request(wpa_ctl, msg, sizeof(msg), msg, &len, NULL);
		msg[len - 1] = '\0';
		if(strcmp("OK", msg)) {
			printf("request DISCONNECT returned %d and %s\n", len, msg);
			return -2;
		}
		module_wpa.timeout = -3; //Unregister
	}
	return module_wpa.fd;
}

int wpa_message(void) {
	size_t len = MSG_LEN - 1;
	char msg[MSG_LEN];
	int i;

	//FIXME it happens one in a time it gets here inspite of empty input
	i = wpa_ctrl_pending(wpa_ctl); //it just select...so no need if i just did it
	if(i < 1) {
		printf("WPA NOTHING TO DO\n");
		return 1;
	}

	if(wpa_ctrl_recv(wpa_ctl, msg, &len)) {
		fprintf(stderr, "WPA recv failed\n");
		return 2;
	}
	msg[len] = '\0';
	printf("received: %s\n", msg);
	if(strstr(msg, WPA_EVENT_CONNECTED)) {
		if(register_module(&module_wpa)) {
			fprintf(stderr, "Unable to register module WPA\n");
			return 3;
		} else {
			printf("CONNECTED\n");
			wpa_connected = true;
			return 0;
		}
	}
	if(strstr(msg, WPA_EVENT_DISCONNECTED) ||
			strstr(msg, "Associated with 00:00:00:00:00:00")) {
		if(wpa_connected) {
			printf("DISCONNECTED\n");
			wpa_connected = false;
			return 4;
		}
	}
	return 1;
}

void wpa_close(void) {
	if(wpa_ctrl_detach(wpa_ctl)) {
		fprintf(stderr, "WPA detach failed\n");
	}
	wpa_ctrl_close(wpa_ctl);
}

