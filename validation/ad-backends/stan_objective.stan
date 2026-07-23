data {
  int<lower=1, upper=2> case_id;
  int<lower=0> N;
  int<lower=1> K;
  matrix[N, K] x;
  array[N] int<lower=0, upper=1> y;
}
parameters {
  vector[K] beta;
}
model {
  if (case_id == 1) {
    for (index in 1:(K - 1)) {
      target += -100 * square(beta[index + 1] - square(beta[index]));
      target += -square(1 - beta[index]);
    }
  } else {
    y ~ bernoulli_logit(x * beta);
  }
}
