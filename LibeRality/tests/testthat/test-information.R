test_that("the teaching design validates and has usable information", {
  example <- lity_example()
  validation <- lity_validate(example$design)
  expect_true(validation$valid)

  information <- lity_information(example$design)
  expect_s3_class(information, "lity_information")
  expect_equal(information$matrix, t(information$matrix), tolerance = 1e-10)
  expect_equal(information$rank, nrow(information$matrix))
  expect_true(all(is.finite(information$se)))
  expect_true(all(information$eigenvalues >= -1e-8))
})

test_that("the native assembler matches a simple Gaussian result", {
  result <- LibeRality:::lity_fim_cpp(
    matrix(c(1, 2), ncol = 1), diag(2),
    list(matrix(0, 2, 2))
  )
  expect_equal(drop(result$information), 5, tolerance = 1e-12)
  expect_equal(result$observation_covariance_rank, 2)
})

test_that("information-dependent precision constraints do not recurse", {
  design <- lity_example()$design
  design$constraints <- list(
    precision = lity_constraint("RSE below 100%", "max_rse", 100)
  )
  expect_true(lity_validate(design)$valid)
  evaluation <- lity_evaluate(design, lity_criterion_D())
  expect_true(evaluation$constraints$feasible)
  expect_true(evaluation$constraints$value < 100)
})

test_that("non-continuous endpoint families produce finite information", {
  design <- lity_example()$design
  designs <- list(
    binary = lity_endpoint("Response", "binary"),
    ordinal = lity_endpoint("Grade", "ordinal", thresholds = c(-1, 0, 1)),
    count = lity_endpoint("Count", "count"),
    event = lity_endpoint("Event", "time_to_event"),
    recurrent = lity_endpoint("Recurrent event", "recurrent_event")
  )
  for (endpoint in designs) {
    design$endpoints <- list(outcome = endpoint)
    information <- lity_information(design)
    expect_true(all(is.finite(information$matrix)))
    expect_true(information$rank > 0)
  }
})
