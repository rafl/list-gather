#include "EXTERN.h"
#include "perl.h"
#include "callchecker0.h"
#include "callparser.h"
#include "XSUB.h"

static OP *
pp_take (pTHX)
{
  dSP;
  dMARK;
  dTARGET;

  while (SP > MARK)
    av_push((AV *)TARG, newSVsv(POPs));

  sv_dump(TARG);

  if (GIMME_V != G_VOID)
    PUSHs(&PL_sv_undef);

  RETURN;
}

static OP *
gen_take_op (pTHX_ OP *listop, PADOFFSET gatherer_offset)
{
  OP *takeop;

  NewOpSz(0, takeop, sizeof(UNOP));
  takeop->op_type = OP_RAND;
  takeop->op_ppaddr = pp_take;
  takeop->op_targ = gatherer_offset;
  cUNOPx(takeop)->op_flags = OPf_KIDS;
  cUNOPx(takeop)->op_first = listop;

  return takeop;
}

static OP *
myck_entersub_gather (pTHX_ OP *entersubop, GV *namegv, SV *protosv)
{
  OP *rv2cvop, *pushop, *blkop;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(protosv);

  entersubop = ck_entersub_args_list(entersubop);
  pushop = cUNOPx(entersubop)->op_first;

  if (!pushop->op_sibling)
    pushop = cUNOPx(pushop)->op_first;

  blkop = pushop->op_sibling;

  rv2cvop = blkop->op_sibling;
  blkop->op_sibling = NULL;
  pushop->op_sibling = rv2cvop;
  op_free(entersubop);

  return blkop;
}

static OP *
myck_entersub_take (pTHX_ OP *entersubop, GV *namegv, SV *protosv)
{
  OP *listop, *lastop, *rv2cvop;
  PADOFFSET gatherer_offset;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(protosv);

  gatherer_offset = pad_findmy("@gather::gatherer",
                               sizeof("@gather::gatherer") - 1, 0);

  entersubop = ck_entersub_args_list(entersubop);
  listop = cUNOPx(entersubop)->op_first;

  if (!listop)
    return entersubop;

  entersubop->op_flags &= ~OPf_KIDS;
  cUNOPx(entersubop)->op_first = NULL;
  op_free(entersubop);

  lastop = cLISTOPx(listop)->op_first;
  while (lastop->op_sibling != cLISTOPx(listop)->op_last) {
    lastop = lastop->op_sibling;
  }
  rv2cvop = lastop->op_sibling;

  lastop->op_sibling = NULL;
  cLISTOPx(listop)->op_last = lastop;
  op_free(rv2cvop);

  return gen_take_op(aTHX_ listop, gatherer_offset);
}

#define SVt_PADNAME SVt_PVMG

#ifndef COP_SEQ_RANGE_LOW_set
# define COP_SEQ_RANGE_LOW_set(sv,val) \
  do { ((XPVNV *)SvANY(sv))->xnv_u.xpad_cop_seq.xlow = val; } while (0)
# define COP_SEQ_RANGE_HIGH_set(sv,val) \
  do { ((XPVNV *)SvANY(sv))->xnv_u.xpad_cop_seq.xhigh = val; } while (0)
#endif

static PADOFFSET
pad_add_my_array_pvn (pTHX_ const char *namepv, STRLEN namelen)
{
  PADOFFSET offset;
  SV *namesv, *myvar;

  //myvar = newAV();
  //av_store(PL_comppad, AvFILLp(PL_comppad) + 1, 0);
  myvar = *av_fetch(PL_comppad, AvFILLp(PL_comppad) + 1, 1);
  sv_upgrade(myvar, SVt_PVAV);
  offset = AvFILLp(PL_comppad);
  SvPADMY_on(myvar);

  PL_curpad = AvARRAY(PL_comppad);
  namesv = newSV_type(SVt_PADNAME);
  sv_setpvn(namesv, namepv, namelen);

  COP_SEQ_RANGE_LOW_set(namesv, PL_cop_seqmax);
  COP_SEQ_RANGE_HIGH_set(namesv, PERL_PADSEQ_INTRO);
  PL_cop_seqmax++;

  av_store(PL_comppad_name, offset, namesv);

  return offset;
}

#define GENOP_GATHER_INTRO 0x1

static OP *
mygenop_gather (pTHX_ U32 flags)
{
  OP *pvarop;

  pvarop = newOP(OP_PADAV,
                 (flags & GENOP_GATHER_INTRO) ? (OPpLVAL_INTRO<<8) : 0);
  pvarop->op_targ = (flags & GENOP_GATHER_INTRO)
    ? pad_add_my_array_pvn(aTHX_ "@gather::gatherer",
                           sizeof("@gather::gatherer") - 1)
    : pad_findmy("@gather::gatherer",
                 sizeof("@gather::gatherer") - 1, 0);

  return pvarop;
}

static OP *
myparse_args_gather (pTHX_ GV *namegv, SV *psobj, U32 *flagsp)
{
  int blk_floor;
  OP *blkop, *initop;

  PERL_UNUSED_ARG(namegv);
  PERL_UNUSED_ARG(psobj);

  lex_read_space(0);
  if (lex_peek_unichar(0) != '{')
    croak("syntax error");
  lex_read_unichar(0);

  blk_floor = Perl_block_start(aTHX_ 1);
  initop = mygenop_gather(aTHX_ GENOP_GATHER_INTRO);
  blkop = op_prepend_elem(OP_LINESEQ, initop,
                          parse_stmtseq(0));
  /* TODO: readonly guard */
  blkop = op_append_elem(OP_LINESEQ, blkop, newOP(OP_UNSTACK, 0));
  blkop = op_append_elem(OP_LINESEQ, blkop, mygenop_gather(aTHX_ 0));
  blkop = Perl_block_end(aTHX_ blk_floor, blkop);

  if (lex_peek_unichar(0) != '}')
    croak("syntax error");
  lex_read_unichar(0);

  *flagsp |= CALLPARSER_PARENS; /* FIXME: ??? */

  return op_scope(blkop);
}

MODULE = gather  PACKAGE = gather

void
gather (...)
  CODE:
    PERL_UNUSED_VAR(items);
    croak("gather called as a function");

void
take (...)
  CODE:
    PERL_UNUSED_VAR(items);
    croak("gather called as a function");

BOOT:
{
  CV *gather_cv, *take_cv;

  gather_cv = get_cv("gather::gather", 0);
  take_cv = get_cv("gather::take", 0);

  cv_set_call_parser(gather_cv, myparse_args_gather, &PL_sv_undef);

  cv_set_call_checker(gather_cv, myck_entersub_gather,
                      (SV*)gather_cv);
  cv_set_call_checker(take_cv, myck_entersub_take,
                      (SV*)take_cv);
}

