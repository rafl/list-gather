#include "EXTERN.h"
#include "perl.h"
#include "callchecker0.h"
#include "XSUB.h"

/* FIXME: thread safety */
static AV *gatherers;

static void
call_gather_coderef (pTHX_ SV *coderef)
{
  dSP;
  ENTER;
  SAVETMPS;
  PUSHMARK(SP);
  call_sv(coderef, G_VOID|G_DISCARD);
  FREETMPS;
  LEAVE;
}

static OP *
pp_gather (pTHX)
{
  dSP;
  AV *gatherer;

  av_push(gatherers, newAV());
  call_gather_coderef(aTHX_ POPs);

  gatherer = av_pop(gatherers);

  if (GIMME_V != G_VOID) {
    I32 i, n_gathered = av_len(gatherer);

    if (n_gathered >= 0) {
      EXTEND(SP, n_gathered + 1);

      for (i = 0; i <= n_gathered; i++) {
        mPUSHs(newSVsv(*av_fetch(gatherer, i, 0)));
      }
    }
  }

  SvREFCNT_dec(gatherer);

  RETURN;
}

static OP *
pp_take (pTHX)
{
  dSP;
  dMARK;
  AV *gatherer;

  gatherer = *av_fetch(gatherers, av_len(gatherers), 0);

  while (SP > MARK)
    av_push(gatherer, POPs);

  if (GIMME_V != G_VOID)
    PUSHs(&PL_sv_undef);

  RETURN;
}

static OP *
gen_gather_op (pTHX_ OP *argop)
{
  OP *gatherop;

  NewOpSz(0, gatherop, sizeof(UNOP));
  gatherop->op_type = OP_RAND;
  gatherop->op_ppaddr = pp_gather;
  cUNOPx(gatherop)->op_flags = OPf_KIDS;
  cUNOPx(gatherop)->op_first = argop;

  return gatherop;
}

static OP *
gen_take_op (pTHX_ OP *listop)
{
  OP *takeop;

  NewOpSz(0, takeop, sizeof(UNOP));
  takeop->op_type = OP_RAND;
  takeop->op_ppaddr = pp_take;
  cUNOPx(takeop)->op_flags = OPf_KIDS;
  cUNOPx(takeop)->op_first = listop;

  return takeop;
}

static OP *
myck_entersub_gather (pTHX_ OP *entersubop, GV *namegv, SV *protosv)
{
  OP *pushop, *argop;

  entersubop = ck_entersub_args_proto(entersubop, namegv, protosv);
  pushop = cUNOPx(entersubop)->op_first;
  if (!pushop->op_sibling)
    pushop = cUNOPx(pushop)->op_first;

  argop = pushop->op_sibling;
  if (!argop)
    return entersubop;

  pushop->op_sibling = argop->op_sibling;
  argop->op_sibling = NULL;
  op_free(entersubop);

  return gen_gather_op(aTHX_ argop);
}

static OP *
myck_entersub_take (pTHX_ OP *entersubop, GV *namegv, SV *protosv)
{
  OP *pushop, *argop = NULL, *listop, *lastop, *rv2cvop;

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

  return gen_take_op(aTHX_ listop);
}

MODULE = gather  PACKAGE = gather

void
gather (...)
  PROTOTYPE: $
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

  cv_set_call_checker(gather_cv, myck_entersub_gather,
                      (SV*)gather_cv);
  cv_set_call_checker(take_cv, myck_entersub_take,
                      (SV*)take_cv);

  gatherers = newAV();
}

