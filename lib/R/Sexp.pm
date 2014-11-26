package R::Sexp;

use strict;
use warnings;

use Inline with => qw(R::Inline::Rinline R::Inline::Rpdl R::Inline::Rutil);
use Inline 'C';
use Capture::Tiny qw(capture_stdout);

use overload '""' => \&string;

sub string {
	my ($self) = @_;
	# TODO change this to properly use R's callbacks instead of Capture::Tiny
	my $str = capture_stdout {
		$self->_string;
	};
	$str =~ s/\n$//s;
	return $str;
}

1;

__DATA__
__C__

#include "rintutil.c"

int op_equal_all(SEXP self, SEXP other) {
	SEXP r_equal, r_all;
	SEXP r_equal_lang, r_all_lang;
	SEXP r_eq_logical;
	int result;

	PROTECT( r_equal = install("==") );
	PROTECT( r_all = install("all") );
	PROTECT( r_equal_lang = lang3( r_equal, self, other) );
	PROTECT( r_all_lang = lang2( r_all, r_equal_lang ) );

	PROTECT( r_eq_logical = eval( r_all_lang, R_GlobalEnv) );

	UNPROTECT(4); /* r_equal, r_all, r_equal_lang, r_all_lang */

	result = INTEGER(r_eq_logical)[0];

	UNPROTECT(1); /* r_eq_logical */

	return result;
}

SEXP eval_lang2( SEXP self, char* func_name ) {
	SEXP r_func_name, result;

	PROTECT( r_func_name = install(func_name) );

	PROTECT( result = eval(lang2(r_func_name, self), R_GlobalEnv) ); /* TODO UNPROTECT */

	UNPROTECT( 1 ); /* r_func_name */

	return result;
}

SEXP attrib( SEXP self, char* name ) {
	SEXP r_name;
	SEXP attr;

	PROTECT( r_name = mkString(name) );

	PROTECT( attr = getAttrib(self, r_name) ); /* UNPROTECT at DESTROY */

	UNPROTECT(1); /* r_name */

	return attr;
}

char* r_class( SEXP self ) {
	/* TODO */
	/* see note about R_data_class in rpy2/rpy/rinterface/sexp.c
	 *
	 * > R_data_class is not exported, although R's own
	 * > package "methods" needs it as part of the API
	 */
	return strsxp_to_charptr(
			R_data_class(self, (Rboolean) 0)
		);
}

char* r_typeof( SEXP self ) {
	/* TODO */
	SEXP r_typeof, result;

	PROTECT( r_typeof = install("typeof") );

	result = eval(lang2(r_typeof, self), R_GlobalEnv);

	UNPROTECT( 1 ); /* r_typeof */

	return strsxp_to_charptr( result );
}

char* _string( SEXP self ) {
	Rf_PrintValue( self );
	return ""; /* TODO use the R output hooks to redirect print messages to string, c.f. R_INTERFACE_PTRS, ptr_R_ */
}
