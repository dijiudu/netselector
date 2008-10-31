%{
#include <stdio.h>
#include <stdarg.h>

#include "netsummoner.h"
#include "list.h"

int yylex(void);
void yyerror (char const *err);
void make_rule_ret(struct rule_ret *rule, unsigned count, ...);
static inline void new_network(char *name, unsigned target_score, struct rule_set *rules);
static inline void new_action(char *name, struct action_plan *plan);
static inline void new_assembly(char *net_n, char *act_n, int type);

unsigned counter, counter_max;
extern char const *yytext;
%}

%locations

%union {
	char *str;
	int num;

	struct rule_ret rule_ret;
	struct rule item;
	struct rule_set *rule_set;
	struct action_plan action_plan;
	struct action_plan *paction_plan;
}

%token <num> VAL_NUM
%token <str> VAL_STR VAL_IP VAL_MAC

%token <num> NETWORK ACTION ASSEMBLY
%token <num> WIFI STP GATEWAY DHCPS NBNS EAP WLCCP CDP DNS
%token <num> MAC ESSID NAME IP ROOT 
%token <num> DHCP ID EXECUTE NOT USE MATCH DOWN ON

%type <rule_set> nstmt nstmtn
%type <rule_ret> wifi stp gateway dhcps nbns eap wlccp cdp dns
%type <item> ip mac essid
%type <action_plan> execute use
%type <paction_plan> astmt
%type <num> atype

%%

config: /* empty */
	| decl config
	;

decl: network
	| action
	| assembly
	;

network: NETWORK VAL_STR VAL_NUM { counter = 0; } '{' nstmt '}' { new_network($2, $3, $6); }
	;

nstmt: /* empty */ { $$ = malloc(sizeof(struct rule) * counter); counter_max = counter--; }
	| WIFI wifi nstmtn { $$ = $3; }
	| STP stp nstmtn { $$ = $3; }
	| GATEWAY gateway nstmtn { $$ = $3; }
	| DHCPS dhcps nstmtn { $$ = $3; }
	| NBNS nbns nstmtn { $$ = $3; }
	| EAP eap nstmtn { $$ = $3; }
	| WLCCP wlccp nstmtn { $$ = $3; }
	| CDP cdp nstmtn { $$ = $3; }
	| DNS dns nstmtn { $$ = $3; }
	;

nstmtn: VAL_NUM { counter++; } nstmt { $3[counter].score = $1; $3[counter].matched = 0;
			$3[counter].type = $<num>-1; $3[counter].items = $<rule_ret>0.items;
			$3[counter].count = $<rule_ret>0.count; counter--; $$ = $3; }
	;

wifi: mac { make_rule_ret(&$$, 1, &$1); }
	| essid  { make_rule_ret(&$$, 1, &$1); }
	| mac essid { make_rule_ret(&$$, 2, &$1, &$2); }
	| essid mac { make_rule_ret(&$$, 2, &$1, &$2); }
	;

stp: ROOT VAL_MAC { struct rule r = { .type = $1, .data = $2 }; make_rule_ret(&$$, 1, &r); }
	;

gateway: ip { make_rule_ret(&$$, 1, &$1); }
	|  mac { make_rule_ret(&$$, 1, &$1); }
	|  ip mac { make_rule_ret(&$$, 2, &$1, &$2); }
	|  mac ip { make_rule_ret(&$$, 2, &$1, &$2); }
	;

dhcps: ip { make_rule_ret(&$$, 1, &$1); }
	|  mac { make_rule_ret(&$$, 1, &$1); }
	|  ip mac { make_rule_ret(&$$, 2, &$1, &$2); }
	|  mac ip { make_rule_ret(&$$, 2, &$1, &$2); }
	;

nbns: NAME VAL_STR { struct rule r = { .type = $1, .data = $2 }; make_rule_ret(&$$, 1, &r); }
	;

eap: mac { make_rule_ret(&$$, 1, &$1); }
	;

wlccp: mac { make_rule_ret(&$$, 1, &$1); }
	;

cdp: ID VAL_STR { struct rule r = { .type = $1, .data = $2 }; make_rule_ret(&$$, 1, &r); }
	;

dns: ip { make_rule_ret(&$$, 1, &$1); }
	;

mac: MAC VAL_MAC { $$.type = $1; $$.data = $2; }
	| NOT MAC VAL_MAC { $$.type = -$2; $$.data = $3; }
	;
ip: IP VAL_IP { $$.type = $1; $$.data = $2; }
	| NOT IP VAL_IP { $$.type = -$2; $$.data = $3; }
	;

essid: ESSID VAL_STR { $$.type = $1; $$.data = $2; }
	| NOT ESSID VAL_STR { $$.type = -$2; $$.data = $3; }
	;

action: ACTION VAL_STR { counter = 0; } '{' astmt '}' { new_action($2, $5); }
	;

astmt: /* empty */ { $$ = malloc(sizeof(struct action_plan) * counter); counter_max = counter--; }
	| execute { counter++; } astmt { $$ = $3; $3[counter].type = $1.type; $3[counter].data = $1.data; counter--; }
	| use { counter++; } astmt { $$ = $3; $3[counter].type = $1.type; $3[counter].data = $1.data; counter--; }
	;

execute: EXECUTE VAL_STR { $$.type = $1; $$.data = $2; }
	;

use: USE DHCP { $$.type = $2; $$.data = NULL; }
	| USE EAP VAL_STR { $$.type = $2; $$.data = $3; }
	;

assembly: ASSEMBLY VAL_STR atype VAL_STR { new_assembly($2, $4, $3); }
	;

atype: ON MATCH { $$ = $2; }
	| ON DOWN { $$ = $2; }
	;

%%

void yyerror (char const *err) {
	//fprintf(stderr, "Bison: %s ", err);
	fprintf(stderr, "Unexpected symbol %s at line %d\n", yytext, yylloc.first_line);
}

void make_rule_ret(struct rule_ret *rule, unsigned count, ...) {
	va_list v;
	struct rule *i;

	va_start(v, count);

	rule->count = count;
	rule->items = malloc(sizeof(struct rule) * count);
	while(count--) {
		i = va_arg(v, struct rule *);
		rule->items[count].type = i->type;
		rule->items[count].data = i->data;
		rule->items[count].matched = 0;
	}
	va_end(v);
}

static inline void new_network(char *name, unsigned target_score, struct rule_set *rules) {
	struct network *net;
	
	net = list_network_add();
	net->rules = rules;
	net->name = name;
	net->target_score = target_score;
	net->count = counter_max;
}

static inline void new_action(char *name, struct action_plan *plan) {
	struct action *act;

	act = list_action_add();
	act->name = name;
	act->actions = plan;
	act->count = counter_max;
}

static inline void new_assembly(char *net_n, char *act_n, int type) {
	struct assembly *asme;

	asme = list_assembly_add();
	asme->net_name = net_n;
	asme->act_name = act_n;
	asme->type = type;
}
