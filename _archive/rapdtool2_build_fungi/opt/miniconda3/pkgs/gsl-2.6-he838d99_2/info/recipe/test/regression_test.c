#include <stdio.h>
#include <gsl_rng.h>
#include <gsl_randist.h>

int main(int argv, char* argc[])
{
  // Regression test for https://github.com/conda-forge/ipopt-feedstock/issues/57
  gsl_rng *r = gsl_rng_alloc(gsl_rng_mt19937);
  
  if (r == NULL) 
  {
    return 1;
  }
  
  gsl_rng_free(r);

  return 0;
}
