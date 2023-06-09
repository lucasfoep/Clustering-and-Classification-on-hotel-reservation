# Summary:
  
# Data was overall pretty clean. A few variables had outliers, which were easily
# removed, and two variables were incongruent (no_of_previous_cancellations and
# no_of_previous_bookings_not_cancelled) thus removed. One variable, lead_time,
# was right skewed and required a log transformation. There was no multicollinearity
# in the dataset. Pre-processing required sampling(due to the size of the dataset),
# some feature engineering, creating dummy variables and standardization. All these
# steps allowed for clusterization and classification.

# K-Means performed surprisingly well considering how intertwined both classes are.
# All three classifiers (KNN, SVM and Decision trees) had virtually the same accuracy,
# at about .79 but precision and recall for decision trees, the model chosen, were
# low due to class imbalance, as denoted by a low kappa.

# Sampling didn't affect results as accuracy, precision and recall were all
# virtually the same when running decision trees on the full dataset.


# Setting seed to get consistent results on stochastic models
set.seed(1)

# Importing libraries
library(caret)
library(pROC)
library(stats)
library(factoextra)
library(ggplot2)
library(tidyverse)
library(kknn)
library(rpart)
library(lubridate)
library(psych)
library(tis)
library(GGally)
library(plotly)

# Loading dataframe
hotel.res <- read.csv('Hotel Reservations.csv')

# Exploratory data analysis

# Looking at variable types and descriptive statistics to get a better
# understanding of variables and their distributions. Of course, there are some
# variables for which measures of spread don't make sense, such as Booking_ID,
# type_of_meal_plan*, required_car_parking_space, room_type_reserved and any other
# categorical variables. Apparently there are no missing values in the dataset.
summary(hotel.res)
describe(hotel.res)

# Grabbing numeric variables for a brief statistical analysis
numeric.hotel.res <- subset(hotel.res, select = c(no_of_adults, no_of_children,
                                                  no_of_weekend_nights, no_of_week_nights,
                                                  lead_time, no_of_previous_cancellations,
                                                  no_of_previous_bookings_not_canceled,
                                                  avg_price_per_room,
                                                  no_of_special_requests))

# Plotting a correlation matrix
# Two things can be seen on this plot:
# 1) All numeric variables, except for number of adults, is highly rightly skewed,
# which might require some adjustments.
# 2) There is no multicollinearity, which is helpful
ggpairs(numeric.hotel.res, columns = 1:ncol(numeric.hotel.res), title = "NumericVars",  
        axisLabels = "show", columnLabels = colnames(numeric.hotel.res))

# Missing values don't seem to be an issue, but outliers are still present.

# 36275 rows in the dataset before removing outliers
nrow(hotel.res)

# Looking at distribution more closely:
# Looks like there are some reservations made without any adults, which should
# not be possible, and, therefore, should be removed.
ggplot(hotel.res, aes(no_of_adults)) + geom_histogram()

# Removing it and looking at it again
hotel.res <- subset(hotel.res, hotel.res$no_of_adults > 0)
ggplot(hotel.res, aes(no_of_adults)) + geom_histogram()

# Looking at next numeric variable: no_of_children. No visible outliers there
ggplot(hotel.res, aes(no_of_children)) + geom_histogram()

# There seems to be some outliers here that can be removed
ggplot(hotel.res, aes(no_of_weekend_nights)) + geom_histogram()

# Removing them and looking at the distribution again.
hotel.res <- subset(hotel.res, hotel.res$no_of_weekend_nights < 4)
ggplot(hotel.res, aes(no_of_weekend_nights)) + geom_histogram()

# Next variable: no_of_week_nights
ggplot(hotel.res, aes(no_of_week_nights)) + geom_histogram()

# Removing outliers for this variable as well
hotel.res <- subset(hotel.res, hotel.res$no_of_week_nights < 8)
ggplot(hotel.res, aes(no_of_week_nights)) + geom_histogram()

# Looking at lead_time
ggplot(hotel.res, aes(lead_time)) + geom_histogram()

# Using IQR to remove outliers. This variable is still highly rightly skewed
# after removing outliers and will need a log transformation.
# Calculating quartiles
quartiles.lt <- quantile(hotel.res$lead_time, probs=c(.25, .75), na.rm = FALSE)

IQR.lt <- IQR(hotel.res$lead_time)

Lower <- quartiles.lt[1] - 1.5*IQR.lt
Upper <- quartiles.lt[2] + 1.5*IQR.lt 

hotel.res <- subset(hotel.res, hotel.res$lead_time > Lower & hotel.res$lead_time < Upper)

ggplot(hotel.res, aes(lead_time)) + geom_histogram()

# Performing a log transformation on lead_time. Using log(data + 1) because the
# majority of the data for this variable is equal to zero.
hotel.res$lead_time <- log(hotel.res$lead_time + 1)

# Looking at the variable's distribution once again. Not right skewed anymore.
ggplot(hotel.res, aes(lead_time)) + geom_histogram()

# Looking at no_of_previous_cancellations and no_of_previous_bookings_not_canceled.
# There is a shocking amount of zeros for both variables, which is illogical
# considering that a person either canceled or not. It could be the case that the
# person never made a reservation, but then they neither should be listed nor let
# alone should have values for other variables. These two variables seem to be
# compromised and will be removed altogether.
ggplot(hotel.res, aes(no_of_previous_cancellations)) + geom_histogram()
ggplot(hotel.res, aes(no_of_previous_bookings_not_canceled)) + geom_histogram()

# Removing variables from dataset
hotel.res <- subset(hotel.res, select = -c(no_of_previous_cancellations,
                                           no_of_previous_bookings_not_canceled))

# Looking at avg_price_per_room. There seems to be some outliers here as well.
ggplot(hotel.res, aes(avg_price_per_room)) + geom_histogram()

# Using IQR to remove outliers
# Calculating quartiles
quartiles.avgp <- quantile(hotel.res$avg_price_per_room, probs=c(.25, .75), na.rm = FALSE)

IQR.avgp <- IQR(hotel.res$avg_price_per_room)

Lower <- quartiles.avgp[1] - 1.5*IQR.avgp
Upper <- quartiles.avgp[2] + 1.5*IQR.avgp

hotel.res <- subset(hotel.res,
                    hotel.res$avg_price_per_room > Lower & hotel.res$avg_price_per_room < Upper)

ggplot(hotel.res, aes(avg_price_per_room)) + geom_histogram()

# Looking at no_of_special_requests. Seems fine.
ggplot(hotel.res, aes(no_of_special_requests)) + geom_histogram()

# Checking how many rows are present on the dataset now: 32972. A significant
# amount of rows was removed to improve distributions.
nrow(hotel.res)

# Updating numeric.hotel.res
numeric.hotel.res <- subset(hotel.res, select = c(no_of_adults, no_of_children,
                                                  no_of_weekend_nights,
                                                  no_of_week_nights, lead_time,
                                                  avg_price_per_room,
                                                  no_of_special_requests))

# Plotting a correlation matrix again to see how the relationship between
# variables changed.
ggpairs(numeric.hotel.res, columns = 1:ncol(numeric.hotel.res), title = "NumericVars",  
        axisLabels = "show", columnLabels = colnames(numeric.hotel.res))

# Taking a look at some descriptive statistics again to asses how the changes
# made impacted the data.
summary(hotel.res)
describe(hotel.res)


# Data pre-processing


# Sampling dataframe so that it is not so computationally expensive.
sample.hotel.res <- hotel.res %>%
  sample_frac(.1)

# Creating a column to determine whether there is a holiday during the stay of
# a given  customer, so that we can try to drive some insight from the date columns,
# given that we already know the distribution of week and weekend nights.
# Starting by combining all arrival columns into one arrival date column
sample.hotel.res <- sample.hotel.res %>%
  unite('Arrival.date', arrival_year:arrival_date, sep = '-')

# Now making it a date type
sample.hotel.res$Arrival.date <- sample.hotel.res$Arrival.date %>%
  as_date()

# Removing the NAs produced
sample.hotel.res <- na.omit(sample.hotel.res)

# Creating column to store whether there was a holiday during the stay
sample.hotel.res$Holiday <- 0

# Checking if there is a holiday between arrival and departure. Incredibly
# inefficient for such a big dataset, but couldn't find a vectorized way of doing this.

# Iterates each row of dataframe
for(i in 1:nrow(sample.hotel.res))
{
  # Calculates time of stay for that row
  time.range <- sample.hotel.res[i, 4] + sample.hotel.res[i, 5]
  
  # Iterates from zero to to end of time range
  for(j in 0:time.range)
  {
    # If there is a holiday during the stay
    if(isHoliday(sample.hotel.res[i, 10] + j, board = T) == TRUE)
    {
      # Assign one to holiday column
      sample.hotel.res[i, ncol(sample.hotel.res)] <- 1
    }
  }
}

# Removing Arrival Date column
sample.hotel.res <- subset(sample.hotel.res, select = -c(Arrival.date, Booking_ID))

# Creating dummy variables so that categorical variables can be used
dummies <- dummyVars(booking_status ~ ., data = sample.hotel.res)
dummy.hotel.res <- as.data.frame(predict(dummies, newdata = sample.hotel.res))

# Storing target variable
target <- sample.hotel.res$booking_status

# Using PCA for dimensionality reduction so that visualization can be used.
# Using prcomp to calculate PCs
hotel.res.pca <- prcomp(dummy.hotel.res)

# Looking at cumulative proportion for two PCs
summary(hotel.res.pca)

# Creating components
preProc <- preProcess(dummy.hotel.res, method="pca", pcaComp=2)
hotel.res.pca <- predict(preProc, dummy.hotel.res)

# Putting back target column
hotel.res.pca$Booking.status <- target

# Changing label Canceled to Red and Not_Canceled to Blue, to make it easier to plot it
hotel.res.pca <- hotel.res.pca %>%
  mutate(Booking.status = case_when(
    Booking.status == 'Canceled' ~ 'Red',
    Booking.status == 'Not_Canceled' ~ 'Blue',
    TRUE ~ Booking.status
  ))

# Looking at it
head(hotel.res.pca)

# Creating a scatterplot. This pattern of clustering will be really hard to
# replicate, but I think Kmeans might do a better job than HAC.
ggplot(hotel.res.pca, aes(x = PC1, y = PC2)) +
  geom_point(color = hotel.res.pca$Booking.status)

# Apply normalization/standardization here so as to avoid having variables with
# larger values taking over 
preproc <- preProcess(dummy.hotel.res, method=c("center", "scale"))
norm.hotel.res <- predict(preproc, dummy.hotel.res)

```

Exploring clusterization
```{r}

# Looking at the scatter plot above I believe something like 10 clusters will
# produce the best possible results, but let's check. There is no knee, really,
# as it keeps dropping until 10 clusters, and although the silhouette is greatest
# at seven clusters, the silhouette at 9 and 10 clusters is pretty similar to the
# one at seven clusters. Considering that on the scatter plot it is easy to see
# that ten clusters are present, I'm going to stick with 10 clusters.
fviz_nbclust(norm.hotel.res, kmeans, method = "wss")
fviz_nbclust(norm.hotel.res, kmeans, method = "silhouette")

# Fitting the data
kmeans.fit <- kmeans(norm.hotel.res, centers = 10, nstart = 30)

# Looking at what clusters the algorithm came up with, and it seems like it didn't
# do too terrible of a job after all.
fviz_cluster(kmeans.fit, data = norm.hotel.res)

# Making a dataframe with the results
results <- data.frame(Booking_Status = target, Kmeans = kmeans.fit$cluster)

# Looking at how kmeans distributed booking status into different clusters.
results %>%
  group_by(Kmeans) %>%
  select(Kmeans, Booking_Status) %>%
  table()

```

Classification

# Creating a train control object
ctrl <- trainControl(method="cv", number = 10)

# Decision trees

# Making valid column names 
colnames(norm.hotel.res) <- make.names(colnames(norm.hotel.res))

# Putting target back in the dataset
norm.hotel.res$Target <- target

# Partitioning the data
index = createDataPartition(y= norm.hotel.res$Target, p=0.8, list=FALSE)

# Creating train set
train_set = norm.hotel.res[index,]

# Creating test set
test_set = norm.hotel.res[-index,]

# Creating empty lists to store results of simulations
a_train_list = list()
a_test_list = list()
nodes_list = list()
maxdepth_list = list()
minbucket_list = list()
minsplit_list = list()

for (i in 1:30)
{
  # Creating maxdepth, minbucket and minsplit
  maxdepth = i
  minbucket = maxdepth * 29
  minsplit = minbucket * 3
  
  # Defining hyper parameters
  hypers = rpart.control(minsplit = minsplit, maxdepth = maxdepth,
                         minbucket = minbucket)
  
  # Fitting model
  tree <- train(Target ~., data = train_set, control = hypers, trControl = ctrl,
                method = "rpart1SE")
  
  # Making predictions for training set
  pred_tree <- predict(tree, train_set)
  
  # Confusion matrix for training set
  cfm_train <- confusionMatrix(as.factor(train_set$Target), pred_tree)
  
  # Making predictions for test set
  pred_tree <- predict(tree, test_set)
  
  # Confusion matrix for test set
  cfm_test <- confusionMatrix(as.factor(test_set$Target), pred_tree)
  
  # Getting training accuracy
  a_train <- cfm_train$overall[1]
  
  # Getting test accuracy
  a_test <- cfm_test$overall[1]
  
  # Getting number of nodes
  nodes <- nrow(tree$finalModel$frame)
  
  # Adding to lists
  a_train_list <- append(a_train_list, a_train)
  a_test_list <- append(a_test_list, a_test)
  nodes_list <- append(nodes_list, nodes)
  maxdepth_list <- append(maxdepth_list, maxdepth)
  minbucket_list <- append(minbucket_list, minbucket)
  minsplit_list <- append(minsplit_list, minsplit)
}

# Creating a nested list
pred_table = list(number.of.nodes = nodes_list,
                  train.accuracy = a_train_list,
                  test.accuracy = a_test_list,
                  max.depth = maxdepth_list,
                  min.bucket = minbucket_list,
                  min.split = minsplit_list
)

# Creating dataframe
df <- as.data.frame(do.call(cbind, pred_table))

# Resetting row names
rownames(df) <- 1:nrow(df)

# Unlisting
df$number.of.nodes <- unlist(df$number.of.nodes)
df$train.accuracy <- unlist(df$train.accuracy)
df$test.accuracy <- unlist(df$test.accuracy)
df$max.depth <- unlist(df$max.depth)
df$min.bucket <- unlist(df$min.bucket)
df$min.split <- unlist(df$min.split)

# Looking at table. Tree with highest accuracy, of .79, has max depth, min bucket
# and min split equals to, respectively, 5, 145 and 435.
df

# Visualizing distribution
ggplot(df, aes(x=number.of.nodes)) + 
  geom_line(aes(y = train.accuracy), color = "red") + 
  geom_line(aes(y = test.accuracy), color="blue") +
  ylab("Accuracy")

# SVM

# Creating a grid
grid <- expand.grid(C = 10^seq(-5,2,0.5))

# Fitting the model
svm <- train(Target ~., data = norm.hotel.res, method = "svmLinear", 
             trControl = ctrl, tuneGrid = grid)

# View grid search result. Accuracy for best performing model is .788
svm

# Creating a tune grid
tuneGrid <- expand.grid(kmax = 3:7,
                        kernel = c("rectangular", "cos"),
                        distance = 1:3)

# Training model
kknn.fit <- train(Target ~ ., 
                  data = norm.hotel.res,
                  method = 'kknn',
                  trControl = ctrl,
                  tuneGrid = tuneGrid)

# Printing trained model provides report. Accuracy for best performing model is
# about .794
kknn.fit

```

# Exploring further with decision trees: There seems to be some class imbalance,
# given that despite an accuracy of 79% (i.e 79% of all labels produced by the
# model were correct), the model produced a precision of 65% and recall of 72%.
# That means only 65% of all observations classified as canceled are truly canceled
# and only 72% of observations that are labeled as canceled were classified as such.

# Considering that the accuracy for all models is about the same, I will move on
# with decision trees, which are much faster than SVM and KNN.

# Creating a train control object
ctrl <- trainControl(method="cv", number = 10)

# Defining hyper parameters
hypers = rpart.control(minsplit = 435, maxdepth = 5, minbucket = 145)

# Fitting model
tree <- train(Target ~., data = train_set, control = hypers, trControl = ctrl,
              method = "rpart1SE")

# Making predictions for test set
pred_tree <- predict(tree, test_set)
pred_prob <- predict(tree, test_set, type = "prob")

# Confusion matrix for test set
confusionMatrix(as.factor(test_set$Target), pred_tree)

# Storing information from the confusion matrix into variables
tp = 153
fp = 83
fn = 58

# Precision and recall
precision = tp/(tp + fp)
recall = tp/(tp + fn)

# Looking at it
precision
recall

# Replacing labels with binary values
test.bin.target <- test_set %>%
  mutate(Target = case_when(
    Target == 'Canceled' ~ '1',
    Target == 'Not_Canceled' ~ '0',
    TRUE ~ Target
  ))

test.bin.target <- as.numeric(test.bin.target$Target)

# Creating Receiver Operator Characteristics object
roc_obj <- roc((test.bin.target), pred_prob[, 1])

# Printing Receiver Operator Characteristics curve
plot(roc_obj, print.auc=TRUE)

# Experimenting with entire dataframe. Accuracy still .79, precision .67 and
# recall considerably lower at also .67.

# Because decision trees are much faster, it allows me to try using the whole
# dataset instead of a sample, which might return better results. For that reason
# I will repeat some steps:

# Creating a column to determine whether there is a holiday during the stay of a
# given  customer. Starting by combining all arrival columns into one arrival date column.
hotel.res <- hotel.res %>%
  unite('Arrival.date', arrival_year:arrival_date, sep = '-')

# Now making it a date type
hotel.res$Arrival.date <- hotel.res$Arrival.date %>%
  as_date()

# Removing the 33 NAs produced
hotel.res <- na.omit(hotel.res)

# Creating column to store whether there was a holiday during the stay
hotel.res$Holiday <- 0

# Checking if there is a holiday between arrival and departure.

# Iterates each row of dataframe
for(i in 1:nrow(hotel.res))
{
  # Calculates time of stay for that row
  time.range <- hotel.res[i, 4] + hotel.res[i, 5]
  
  # Iterates from zero to end of time range
  for(j in 0:time.range)
  {
    # If there is a holiday during the stay
    if(isHoliday(hotel.res[i, 10] + j, board = T) == TRUE)
    {
      # Assign one to holiday column
      hotel.res[i, ncol(hotel.res)] <- 1
    }
  }
}

# Removing Arrival Date column
hotel.res <- subset(hotel.res, select = -c(Arrival.date, Booking_ID))

# Creating dummy variables so that categorical variables can be used
dummies <- dummyVars(booking_status ~ ., data = hotel.res)
dummy.hotel.res <- as.data.frame(predict(dummies, newdata = hotel.res))

# Storing target variable
target <- hotel.res$booking_status

# Apply normalization/standardization here so as to avoid having variables with
# larger values taking over 
preproc <- preProcess(dummy.hotel.res, method=c("center", "scale"))
norm.hotel.res <- predict(preproc, dummy.hotel.res)

# Making valid column names 
colnames(norm.hotel.res) <- make.names(colnames(norm.hotel.res))

# Putting target back in the dataset
norm.hotel.res$Target <- target

# Partitioning the data
index = createDataPartition(y= norm.hotel.res$Target, p=0.8, list=FALSE)

# Creating train set
train_set = norm.hotel.res[index,]

# Creating test set
test_set = norm.hotel.res[-index,]

# Creating empty lists to store results of simulations
a_train_list = list()
a_test_list = list()
nodes_list = list()
maxdepth_list = list()
minbucket_list = list()
minsplit_list = list()

for (i in 1:30)
{
  # Creating maxdepth, minbucket and minsplit
  maxdepth = i
  minbucket = maxdepth * 292
  minsplit = minbucket * 3
  
  # Defining hyper parameters
  hypers = rpart.control(minsplit = minsplit, maxdepth = maxdepth,
                         minbucket = minbucket)
  
  # Fitting model
  tree <- train(Target ~., data = train_set, control = hypers,
                trControl = ctrl, method = "rpart1SE")
  
  # Making predictions for training set
  pred_tree <- predict(tree, train_set)
  
  # Confusion matrix for training set
  cfm_train <- confusionMatrix(as.factor(train_set$Target), pred_tree)
  
  # Making predictions for test set
  pred_tree <- predict(tree, test_set)
  
  # Confusion matrix for test set
  cfm_test <- confusionMatrix(as.factor(test_set$Target), pred_tree)
  
  # Getting training accuracy
  a_train <- cfm_train$overall[1]
  
  # Getting test accuracy
  a_test <- cfm_test$overall[1]
  
  # Getting number of nodes
  nodes <- nrow(tree$finalModel$frame)
  
  # Adding to lists
  a_train_list <- append(a_train_list, a_train)
  a_test_list <- append(a_test_list, a_test)
  nodes_list <- append(nodes_list, nodes)
  maxdepth_list <- append(maxdepth_list, maxdepth)
  minbucket_list <- append(minbucket_list, minbucket)
  minsplit_list <- append(minsplit_list, minsplit)
}

# Creating a nested list
pred_table = list(number.of.nodes = nodes_list,
                  train.accuracy = a_train_list,
                  test.accuracy = a_test_list,
                  max.depth = maxdepth_list,
                  min.bucket = minbucket_list,
                  min.split = minsplit_list
)

# Creating dataframe
df <- as.data.frame(do.call(cbind, pred_table))

# Resetting row names
rownames(df) <- 1:nrow(df)

# Unlisting
df$number.of.nodes <- unlist(df$number.of.nodes)
df$train.accuracy <- unlist(df$train.accuracy)
df$test.accuracy <- unlist(df$test.accuracy)
df$max.depth <- unlist(df$max.depth)
df$min.bucket <- unlist(df$min.bucket)
df$min.split <- unlist(df$min.split)

# Looking at table. Tree with highest accuracy, of .79, has max depth, min bucket
# and min split equals to, respectively, 4, 1168 and 3504.
df

# Visualizing distribution
ggplot(df, aes(x=number.of.nodes)) + 
  geom_line(aes(y = train.accuracy), color = "red") + 
  geom_line(aes(y = test.accuracy), color="blue") +
  ylab("Accuracy")

# Defining hyper parameters
hypers = rpart.control(minsplit = 3504, maxdepth = 4, minbucket = 1168)

# Fitting model
tree <- train(Target ~., data = train_set, control = hypers, trControl = ctrl,
              method = "rpart1SE")

# Making predictions for test set
pred_tree <- predict(tree, test_set)
pred_prob <- predict(tree, test_set, type = "prob")

# Confusion matrix for test set
confusionMatrix(as.factor(test_set$Target), pred_tree)

# Storing information from the confusion matrix into variables
tp = 1379
fp = 680
fn = 664

# Precision and recall
precision = tp/(tp + fp)
recall = tp/(tp + fn)

# Looking at it
precision
recall

# Replacing labels with binary values
test.bin.target <- test_set %>%
  mutate(Target = case_when(
    Target == 'Canceled' ~ '1',
    Target == 'Not_Canceled' ~ '0',
    TRUE ~ Target
  ))

test.bin.target <- as.numeric(test.bin.target$Target)

# Creating Receiver Operator Characteristics object
roc_obj <- roc((test.bin.target), pred_prob[, 1])

# Printing Receiver Operator Characteristics curve
plot(roc_obj, print.auc=TRUE)
