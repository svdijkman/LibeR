test_that("semantic contracts restore nested result classes", {
  example <- lity_example()
  evaluated <- lity_evaluate(example$design, lity_criterion_D())
  plain <- unclass(evaluated)
  plain$design <- unclass(plain$design)
  plain$design$arms <- lapply(plain$design$arms, unclass)
  restored <- lity_contract_restore(plain)
  expect_s3_class(restored, "lity_evaluation")
  expect_s3_class(restored$design, "lity_design")
  expect_true(all(vapply(restored$design$arms, inherits, logical(1), "lity_arm")))
})

test_that("Pareto contracts retain both public classes", {
  value <- list(schema = "liberality.pareto", version = 1L, designs = list())
  restored <- lity_contract_restore(value)
  expect_s3_class(restored, "lity_pareto")
  expect_s3_class(restored, "lity_optimisation")
  expect_error(lity_contract_restore(list(schema = "other.object")), "not a LibeRality")
})
