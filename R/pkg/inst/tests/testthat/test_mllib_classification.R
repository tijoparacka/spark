#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

library(testthat)

context("MLlib classification algorithms, except for tree-based algorithms")

# Tests for MLlib classification algorithms in SparkR
sparkSession <- sparkR.session(enableHiveSupport = FALSE)

absoluteSparkPath <- function(x) {
  sparkHome <- sparkR.conf("spark.home")
  file.path(sparkHome, x)
}

test_that("spark.logit", {
  # R code to reproduce the result.
  # nolint start
  #' library(glmnet)
  #' iris.x = as.matrix(iris[, 1:4])
  #' iris.y = as.factor(as.character(iris[, 5]))
  #' logit = glmnet(iris.x, iris.y, family="multinomial", alpha=0, lambda=0.5)
  #' coef(logit)
  #
  # $setosa
  # 5 x 1 sparse Matrix of class "dgCMatrix"
  # s0
  #               1.0981324
  # Sepal.Length -0.2909860
  # Sepal.Width   0.5510907
  # Petal.Length -0.1915217
  # Petal.Width  -0.4211946
  #
  # $versicolor
  # 5 x 1 sparse Matrix of class "dgCMatrix"
  # s0
  #               1.520061e+00
  # Sepal.Length  2.524501e-02
  # Sepal.Width  -5.310313e-01
  # Petal.Length  3.656543e-02
  # Petal.Width  -3.144464e-05
  #
  # $virginica
  # 5 x 1 sparse Matrix of class "dgCMatrix"
  # s0
  #              -2.61819385
  # Sepal.Length  0.26574097
  # Sepal.Width  -0.02005932
  # Petal.Length  0.15495629
  # Petal.Width   0.42122607
  # nolint end

  # Test multinomial logistic regression againt three classes
  df <- suppressWarnings(createDataFrame(iris))
  model <- spark.logit(df, Species ~ ., regParam = 0.5)
  summary <- summary(model)

  # test summary coefficients return matrix type
  expect_true(class(summary$coefficients) == "matrix")
  expect_true(class(summary$coefficients[, 1]) == "numeric")

  versicolorCoefsR <- c(1.52, 0.03, -0.53, 0.04, 0.00)
  virginicaCoefsR <- c(-2.62, 0.27, -0.02, 0.16, 0.42)
  setosaCoefsR <- c(1.10, -0.29, 0.55, -0.19, -0.42)
  versicolorCoefs <- summary$coefficients[, "versicolor"]
  virginicaCoefs <- summary$coefficients[, "virginica"]
  setosaCoefs <- summary$coefficients[, "setosa"]
  expect_true(all(abs(versicolorCoefsR - versicolorCoefs) < 0.1))
  expect_true(all(abs(virginicaCoefsR - virginicaCoefs) < 0.1))
  expect_true(all(abs(setosaCoefs - setosaCoefs) < 0.1))

  # Test model save and load
  modelPath <- tempfile(pattern = "spark-logit", fileext = ".tmp")
  write.ml(model, modelPath)
  expect_error(write.ml(model, modelPath))
  write.ml(model, modelPath, overwrite = TRUE)
  model2 <- read.ml(modelPath)
  coefs <- summary(model)$coefficients
  coefs2 <- summary(model2)$coefficients
  expect_equal(coefs, coefs2)
  unlink(modelPath)

  # R code to reproduce the result.
  # nolint start
  #' library(glmnet)
  #' iris2 <- iris[iris$Species %in% c("versicolor", "virginica"), ]
  #' iris.x = as.matrix(iris2[, 1:4])
  #' iris.y = as.factor(as.character(iris2[, 5]))
  #' logit = glmnet(iris.x, iris.y, family="multinomial", alpha=0, lambda=0.5)
  #' coef(logit)
  #
  # $versicolor
  # 5 x 1 sparse Matrix of class "dgCMatrix"
  # s0
  #               3.93844796
  # Sepal.Length -0.13538675
  # Sepal.Width  -0.02386443
  # Petal.Length -0.35076451
  # Petal.Width  -0.77971954
  #
  # $virginica
  # 5 x 1 sparse Matrix of class "dgCMatrix"
  # s0
  #              -3.93844796
  # Sepal.Length  0.13538675
  # Sepal.Width   0.02386443
  # Petal.Length  0.35076451
  # Petal.Width   0.77971954
  #
  #' logit = glmnet(iris.x, iris.y, family="binomial", alpha=0, lambda=0.5)
  #' coef(logit)
  #
  # 5 x 1 sparse Matrix of class "dgCMatrix"
  # s0
  # (Intercept)  -6.0824412
  # Sepal.Length  0.2458260
  # Sepal.Width   0.1642093
  # Petal.Length  0.4759487
  # Petal.Width   1.0383948
  #
  # nolint end

  # Test multinomial logistic regression againt two classes
  df <- suppressWarnings(createDataFrame(iris))
  training <- df[df$Species %in% c("versicolor", "virginica"), ]
  model <- spark.logit(training, Species ~ ., regParam = 0.5, family = "multinomial")
  summary <- summary(model)
  versicolorCoefsR <- c(3.94, -0.16, -0.02, -0.35, -0.78)
  virginicaCoefsR <- c(-3.94, 0.16, -0.02, 0.35, 0.78)
  versicolorCoefs <- summary$coefficients[, "versicolor"]
  virginicaCoefs <- summary$coefficients[, "virginica"]
  expect_true(all(abs(versicolorCoefsR - versicolorCoefs) < 0.1))
  expect_true(all(abs(virginicaCoefsR - virginicaCoefs) < 0.1))

  # Test binomial logistic regression againt two classes
  model <- spark.logit(training, Species ~ ., regParam = 0.5)
  summary <- summary(model)
  coefsR <- c(-6.08, 0.25, 0.16, 0.48, 1.04)
  coefs <- summary$coefficients[, "Estimate"]
  expect_true(all(abs(coefsR - coefs) < 0.1))

  # Test prediction with string label
  prediction <- predict(model, training)
  expect_equal(typeof(take(select(prediction, "prediction"), 1)$prediction), "character")
  expected <- c("versicolor", "versicolor", "virginica", "versicolor", "versicolor",
                "versicolor", "versicolor", "versicolor", "versicolor", "versicolor")
  expect_equal(as.list(take(select(prediction, "prediction"), 10))[[1]], expected)

  # Test prediction with numeric label
  label <- c(0.0, 0.0, 0.0, 1.0, 1.0)
  feature <- c(1.1419053, 0.9194079, -0.9498666, -1.1069903, 0.2809776)
  data <- as.data.frame(cbind(label, feature))
  df <- createDataFrame(data)
  model <- spark.logit(df, label ~ feature)
  prediction <- collect(select(predict(model, df), "prediction"))
  expect_equal(prediction$prediction, c("0.0", "0.0", "1.0", "1.0", "0.0"))
})

test_that("spark.mlp", {
  df <- read.df(absoluteSparkPath("data/mllib/sample_multiclass_classification_data.txt"),
                source = "libsvm")
  model <- spark.mlp(df, label ~ features, blockSize = 128, layers = c(4, 5, 4, 3),
                     solver = "l-bfgs", maxIter = 100, tol = 0.5, stepSize = 1, seed = 1)

  # Test summary method
  summary <- summary(model)
  expect_equal(summary$numOfInputs, 4)
  expect_equal(summary$numOfOutputs, 3)
  expect_equal(summary$layers, c(4, 5, 4, 3))
  expect_equal(length(summary$weights), 64)
  expect_equal(head(summary$weights, 5), list(-0.878743, 0.2154151, -1.16304, -0.6583214, 1.009825),
               tolerance = 1e-6)

  # Test predict method
  mlpTestDF <- df
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 6), c("1.0", "0.0", "0.0", "0.0", "0.0", "0.0"))

  # Test model save/load
  modelPath <- tempfile(pattern = "spark-mlp", fileext = ".tmp")
  write.ml(model, modelPath)
  expect_error(write.ml(model, modelPath))
  write.ml(model, modelPath, overwrite = TRUE)
  model2 <- read.ml(modelPath)
  summary2 <- summary(model2)

  expect_equal(summary2$numOfInputs, 4)
  expect_equal(summary2$numOfOutputs, 3)
  expect_equal(summary2$layers, c(4, 5, 4, 3))
  expect_equal(length(summary2$weights), 64)

  unlink(modelPath)

  # Test default parameter
  model <- spark.mlp(df, label ~ features, layers = c(4, 5, 4, 3))
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 10),
               c("1.0", "1.0", "1.0", "1.0", "0.0", "1.0", "2.0", "2.0", "1.0", "0.0"))

  # Test illegal parameter
  expect_error(spark.mlp(df, label ~ features, layers = NULL),
               "layers must be a integer vector with length > 1.")
  expect_error(spark.mlp(df, label ~ features, layers = c()),
               "layers must be a integer vector with length > 1.")
  expect_error(spark.mlp(df, label ~ features, layers = c(3)),
               "layers must be a integer vector with length > 1.")

  # Test random seed
  # default seed
  model <- spark.mlp(df, label ~ features, layers = c(4, 5, 4, 3), maxIter = 10)
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 10),
               c("1.0", "1.0", "1.0", "1.0", "0.0", "1.0", "2.0", "2.0", "1.0", "0.0"))
  # seed equals 10
  model <- spark.mlp(df, label ~ features, layers = c(4, 5, 4, 3), maxIter = 10, seed = 10)
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 10),
               c("1.0", "1.0", "1.0", "1.0", "0.0", "1.0", "2.0", "2.0", "1.0", "0.0"))

  # test initialWeights
  model <- spark.mlp(df, label ~ features, layers = c(4, 3), maxIter = 2, initialWeights =
    c(0, 0, 0, 0, 0, 5, 5, 5, 5, 5, 9, 9, 9, 9, 9))
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 10),
               c("1.0", "1.0", "1.0", "1.0", "2.0", "1.0", "2.0", "2.0", "1.0", "0.0"))

  model <- spark.mlp(df, label ~ features, layers = c(4, 3), maxIter = 2, initialWeights =
    c(0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 5.0, 5.0, 5.0, 9.0, 9.0, 9.0, 9.0, 9.0))
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 10),
               c("1.0", "1.0", "1.0", "1.0", "2.0", "1.0", "2.0", "2.0", "1.0", "0.0"))

  model <- spark.mlp(df, label ~ features, layers = c(4, 3), maxIter = 2)
  mlpPredictions <- collect(select(predict(model, mlpTestDF), "prediction"))
  expect_equal(head(mlpPredictions$prediction, 10),
               c("1.0", "1.0", "1.0", "1.0", "0.0", "1.0", "0.0", "2.0", "1.0", "0.0"))

  # Test formula works well
  df <- suppressWarnings(createDataFrame(iris))
  model <- spark.mlp(df, Species ~ Sepal_Length + Sepal_Width + Petal_Length + Petal_Width,
                     layers = c(4, 3))
  summary <- summary(model)
  expect_equal(summary$numOfInputs, 4)
  expect_equal(summary$numOfOutputs, 3)
  expect_equal(summary$layers, c(4, 3))
  expect_equal(length(summary$weights), 15)
  expect_equal(head(summary$weights, 5), list(-1.1957257, -5.2693685, 7.4489734, -6.3751413,
               -10.2376130), tolerance = 1e-6)
})

test_that("spark.naiveBayes", {
  # R code to reproduce the result.
  # We do not support instance weights yet. So we ignore the frequencies.
  #
  #' library(e1071)
  #' t <- as.data.frame(Titanic)
  #' t1 <- t[t$Freq > 0, -5]
  #' m <- naiveBayes(Survived ~ ., data = t1)
  #' m
  #' predict(m, t1)
  #
  # -- output of 'm'
  #
  # A-priori probabilities:
  # Y
  #        No       Yes
  # 0.4166667 0.5833333
  #
  # Conditional probabilities:
  #      Class
  # Y           1st       2nd       3rd      Crew
  #   No  0.2000000 0.2000000 0.4000000 0.2000000
  #   Yes 0.2857143 0.2857143 0.2857143 0.1428571
  #
  #      Sex
  # Y     Male Female
  #   No   0.5    0.5
  #   Yes  0.5    0.5
  #
  #      Age
  # Y         Child     Adult
  #   No  0.2000000 0.8000000
  #   Yes 0.4285714 0.5714286
  #
  # -- output of 'predict(m, t1)'
  #
  # Yes Yes Yes Yes No  No  Yes Yes No  No  Yes Yes Yes Yes Yes Yes Yes Yes No  No  Yes Yes No  No
  #

  t <- as.data.frame(Titanic)
  t1 <- t[t$Freq > 0, -5]
  df <- suppressWarnings(createDataFrame(t1))
  m <- spark.naiveBayes(df, Survived ~ ., smoothing = 0.0)
  s <- summary(m)
  expect_equal(as.double(s$apriori[1, "Yes"]), 0.5833333, tolerance = 1e-6)
  expect_equal(sum(s$apriori), 1)
  expect_equal(as.double(s$tables["Yes", "Age_Adult"]), 0.5714286, tolerance = 1e-6)
  p <- collect(select(predict(m, df), "prediction"))
  expect_equal(p$prediction, c("Yes", "Yes", "Yes", "Yes", "No", "No", "Yes", "Yes", "No", "No",
                               "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "No", "No",
                               "Yes", "Yes", "No", "No"))

  # Test model save/load
  modelPath <- tempfile(pattern = "spark-naiveBayes", fileext = ".tmp")
  write.ml(m, modelPath)
  expect_error(write.ml(m, modelPath))
  write.ml(m, modelPath, overwrite = TRUE)
  m2 <- read.ml(modelPath)
  s2 <- summary(m2)
  expect_equal(s$apriori, s2$apriori)
  expect_equal(s$tables, s2$tables)

  unlink(modelPath)

  # Test e1071::naiveBayes
  if (requireNamespace("e1071", quietly = TRUE)) {
    expect_error(m <- e1071::naiveBayes(Survived ~ ., data = t1), NA)
    expect_equal(as.character(predict(m, t1[1, ])), "Yes")
  }

  # Test numeric response variable
  t1$NumericSurvived <- ifelse(t1$Survived == "No", 0, 1)
  t2 <- t1[-4]
  df <- suppressWarnings(createDataFrame(t2))
  m <- spark.naiveBayes(df, NumericSurvived ~ ., smoothing = 0.0)
  s <- summary(m)
  expect_equal(as.double(s$apriori[1, 1]), 0.5833333, tolerance = 1e-6)
  expect_equal(sum(s$apriori), 1)
  expect_equal(as.double(s$tables[1, "Age_Adult"]), 0.5714286, tolerance = 1e-6)
})

sparkR.session.stop()
