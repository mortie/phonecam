#pragma once

#define defsym(x) \
	extern unsigned char x; \
	extern unsigned int x ## _len; \
	__attribute__((unused)) static char *x ## _data = (char *)&x

defsym(web_index_html);
defsym(web_script_js);

#undef defsym
