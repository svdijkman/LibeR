test_that("FO block mode exposes the PopED and PFIM convention", {
  design <- lity_example()$design
  full <- lity_information(design, approximation = "full_gaussian")
  block <- lity_information(design, approximation = "fo_block")
  theta <- which(block$parameters$type == "theta")
  variance <- which(block$parameters$type != "theta")
  expect_equal(
    unname(block$matrix[theta, variance, drop = FALSE]),
    matrix(0, length(theta), length(variance))
  )
  expect_equal(
    unname(block$matrix[variance, variance]),
    unname(full$matrix[variance, variance]), tolerance = 1e-10
  )
  expect_identical(block$diagnostics$approximation, "fo_block")
})

test_that("external parameter transformations use the common variance scale", {
  native <- diag(c(theta = 2, sigma_sd = 8))
  transformed <- LibeRality:::.lity_external_reorder(
    native, c("THETA", "SIGMA"), c("THETA", "SIGMA"), c(1, 2)
  )
  expect_equal(unname(diag(transformed)), c(2, 32))
})

test_that("external fixtures and coverage are versioned", {
  expect_setequal(
    lity_external_validation_fixtures(),
    c("oral_proportional", "bolus_additive", "oral_combined")
  )
  combined <- LibeRality:::.lity_external_fixture_spec("oral_combined")
  expect_true(combined$support[["PopED"]])
  expect_false(combined$support[["PFIM"]])
})

test_that("installed external engines pass the reference fixture", {
  skip_if(Sys.getenv("_LIBERALITY_RUN_EXTERNAL_VALIDATION_") != "true")
  skip_if_not_installed("PopED", minimum_version = "0.7.0")
  skip_if_not_installed("PFIM", minimum_version = "7.0.3")
  result <- lity_external_validate(
    fixtures = "oral_proportional", repetitions = 1L, design_search = FALSE
  )
  expect_true(result$passed)
  expect_true(all(result$comparisons$pass))
})
