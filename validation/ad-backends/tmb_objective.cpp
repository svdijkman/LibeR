#include <TMB.hpp>

template<class Type>
Type objective_function<Type>::operator() () {
  DATA_INTEGER(case_id);
  DATA_MATRIX(x);
  DATA_VECTOR(y);
  PARAMETER_VECTOR(beta);

  Type objective = Type(0);
  if (case_id == 1) {
    for (int index = 0; index + 1 < beta.size(); ++index) {
      objective += Type(100) *
        pow(beta(index + 1) - beta(index) * beta(index), Type(2));
      objective += pow(Type(1) - beta(index), Type(2));
    }
  } else {
    vector<Type> linear = x * beta;
    for (int row = 0; row < linear.size(); ++row) {
      objective += log(Type(1) + exp(linear(row))) - y(row) * linear(row);
    }
  }
  return objective;
}
