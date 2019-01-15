/* This code originated in the internet justbuster.
 */

/* dsplit() takes a domain and returns a pointer to a url_spec
 * structure populated with dbuf, dcnt and dvec.  the other fields
 * in the structure that is returned are zero.
 *
 */

#define DMAX	16
char *strdup();
char *malloc();

char **dsplit(domain, n)
	char	*domain;
	int	*n;
{
	char *dbuf;
	char *v[DMAX];
	int size;
	char *p;

	char **dvec;

    dbuf = strdup(domain);

    /* map to lower case
     */
    for(p = domain; *p ; p++) *p = tolower(*p);

    /* split the domain name into components 
     */
    *n = ssplit(dbuf, ".", v, DMAX, 1, 1);

    if ( (dvec = (char **) malloc(*n * sizeof(char *)) ) ) {
	    memcpy(dvec, v, size);
    }

    return dvec;
}

/* the "pattern" is a domain that may contain a '*' as a wildcard.
 * the "fqdn" is the domain name against which the patterns are compared.
 *
 * domaincmp("a.b.c" , "a.b.c")	=> 0 (MATCH)
 * domaincmp("a*.b.c", "a.b.c")	=> 0 (MATCH)
 * domaincmp("b.c"   , "a.b.c")	=> 0 (MATCH)
 * domaincmp(""      , "a.b.c")	=> 0 (MATCH)
 */

int domaincmp(pattern, domain)
	char *pattern;
	char *domain;
{
	char **pv, **fv;	/* vectors  */
	int    pn,   fn;	/* counters */
	char  *p,   *f;		/* chars    */
	
	pv = dsplit(pattern, &pn);
	fv = dsplit(domain,  &fn);

	while((pn > 0) && (fn > 0)) {
		p = pv[--pn];
		f = fv[--fn];

		while(*p && *f && (*p == tolower(*f))) {
			p++, f++;
		}

		if((*p != tolower(*f)) && (*p != '*')) return(1);
	}

	if(pn > 0) return(1);

	return(0);
}
