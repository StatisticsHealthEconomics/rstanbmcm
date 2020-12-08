// mixture cure model
// joint relative survival
//


functions {
#include /include/distributions.stan
}

// input data ----
data {
  int<lower=0> n_os;            // number of observations
  int<lower=0> n_pfs;

  int<lower=0> H_os;            // number of covariates
  int<lower=0> H_pfs;

  vector[n_os] t_os;             // observation times
  vector[n_pfs] t_pfs;

  vector[n_os] d_os;             // censoring indicator (1 = observed, 0 = censored)
  vector[n_pfs] d_pfs;

  matrix[n_os, H_os] X_os;        // matrix of covariates (with n rows and H columns)
  matrix[n_pfs, H_pfs] X_pfs;

  int distn_os;                // 1: exp; 2: weibull
  int distn_pfs;

  real<lower=0> a_alpha_os[distn_os == 2 ? 1 : 0];
  real<lower=0> b_alpha_os[distn_os == 2 ? 1 : 0];

  real<lower=0> a_alpha_pfs[distn_pfs == 2 ? 1 : 0];
  real<lower=0> b_alpha_pfs[distn_pfs == 2 ? 1 : 0];

  vector[H_os] mu_0_os;
  vector[H_pfs] mu_0_pfs;
  vector<lower=0> [H_os] sigma_0_os;
  vector<lower=0> [H_pfs] sigma_0_pfs;

  vector[H_os] mu_bg;
  vector<lower=0> [H_os] sigma_bg;

  real mu_joint;
  real<lower=0> sigma_joint;

  real a_cf;                  // cure fraction ~ Beta(a,b)
  real b_cf;

  int<lower=0> t_max;
}

parameters {
  vector[H_os] beta_os;       // coefficients in linear predictor (including intercept)
  vector[H_pfs] beta_pfs;
  vector[H_os] beta_bg;
  real beta_joint;
  real<lower=0> alpha1[distn_os == 2 ? 1 : 0];
  real<lower=0> alpha2[distn_pfs == 2 ? 1 : 0];

  real<lower=0, upper=1> curefrac;
}

transformed parameters {
  vector[n_os] lp_os;
  vector[n_pfs] lp_pfs;
  vector[n_os] lp_os_bg;
  vector[n_os] lp_pfs_bg;

  vector[n_os] lambda_os;
  vector[n_pfs] lambda_pfs;
  vector[n_os] lambda_os_bg;
  vector[n_os] lambda_pfs_bg;
  vector[n_pfs] mean_t_pfs;

  lp_pfs = X_pfs*beta_pfs;

  lp_os_bg = X_os*beta_bg;
  lp_pfs_bg = X_pfs*beta_bg;

  // rate parameters
  lambda_pfs = exp(lp_pfs);
  lambda_os_bg = exp(lp_os_bg);
  lambda_pfs_bg = exp(lp_pfs_bg);

  # correlated event times
  if (distn_pfs == 1) {
    // mean_t_pfs = 1/exp(beta_pfs[1]));  // global mean //TODO: should this be adjusted?
    for (i in 1:n_pfs)
      mean_t_pfs[i] = 1/lambda_pfs[i];
  }

  // if (distn_pfs == 2) {
  //   // mean_t_pfs = exp(beta_pfs[1])*tgamma(1 + 1/alpha2);
  //   for (i in 1:n_pfs)
  //     mean_t_pfs[i] = lambda_pfs[i]*tgamma(1 + 1/alpha2);
  // }

  lp_os = X_os*beta_os + beta_joint*(t_pfs - mean_t_pfs);
  //TODO: rate rather than t?
  // lp_os = X_os*beta_os + beta_joint*(lp_pfs - mean_lp_pfs);
  // lp_os = X_os*beta_os + beta_joint*X_pfs[, 2]*beta_pfs[2];

  lambda_os = exp(lp_os);
}

model {
  vector[n_os] distn_os_lpdf;
  vector[n_pfs] distn_pfs_lpdf;

  beta_os ~ normal(mu_0_os, sigma_0_os);
  beta_pfs ~ normal(mu_0_pfs, sigma_0_pfs);
  beta_bg ~ normal(mu_bg, sigma_bg);
  beta_joint ~ normal(mu_joint, sigma_joint);

  if (distn_os == 2)
    alpha1 ~ gamma(a_alpha_os, b_alpha_os);
  if (distn_pfs == 2)
    alpha2 ~ gamma(a_alpha_pfs, b_alpha_pfs);

  curefrac ~ beta(a_cf, b_cf);

  for (i in 1:n_os) {

    if (distn_os == 1)
      distn_os_lpdf[i] = surv_exp_lpdf(t_os[i] | d_os[i], lambda_os_bg[i] + lambda_os[i]);
    // if (distn_os == 2)
    //   distn_os_lpdf[i] = joint_exp_weibull_lpdf(t_os[i] | d_os[i], alpha1, lambda_os[i], lambda_os_bg[i]);

    if (distn_pfs == 1)
      distn_pfs_lpdf[i] = surv_exp_lpdf(t_pfs[i] | d_pfs[i], lambda_pfs_bg[i] + lambda_pfs[i]);
    // if (distn_pfs == 2)
    //   distn_pfs_lpdf[i] = joint_exp_weibull_lpdf(t_pfs[i] | d_pfs[i], alpha2, lambda_pfs[i], lambda_pfs_bg[i]);

    target += log_sum_exp(
                log(curefrac) +
                surv_exp_lpdf(t_os[i] | d_os[i], lambda_os_bg[i]),
                log1m(curefrac) + distn_os_lpdf[i]) +
              log_sum_exp(
                log(curefrac) +
                surv_exp_lpdf(t_pfs[i] | d_pfs[i], lambda_pfs_bg[i]),
                log1m(curefrac) + distn_pfs_lpdf[i]);
  }
}

generated quantities {

}
