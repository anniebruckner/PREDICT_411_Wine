# Wine Decision Tree
# References: 
# http://discuss.analyticsvidhya.com/t/what-are-the-packages-required-to-plot-a-fancy-rpart
# -plot-in-r/6776
# # http://www.r-bloggers.com/in-depth-introduction-to-machine-learning-in-15-hours-of-
# expert-videos/

#install.packages("rpart")
#install.packages("rpart.plot")
#install.packages("RGtk2")
#install.packages("rattle")
#install.packages("RColorBrewer")
library(rpart)
library(rpart.plot)
library(RGtk2)
library(rattle)
library(RColorBrewer)

# Read in file.
wine <- read.csv(file.path("/Users/annie/Desktop/Northwestern/PREDICT_411/Unit03/Wine","wine.csv"),sep=",")

# When you run the str() command it shows you what type of variable each in your data set is.
str(wine)

# Variables to be imputed:
#ResidualSugar
#Chlorides
#FreeSulfurDioxide
#TotalSulfurDioxide
#pH
#Sulphates
#Alcohol
#STARS

WineTreeSTARS <- rpart(STARS ~
                       AcidIndex
                       +Alcohol
                       +Chlorides
                       +CitricAcid
                       +Density
                       +FixedAcidity
                       +FreeSulfurDioxide
                       +LabelAppeal
                       +ResidualSugar
                       +Sulphates
                       +TotalSulfurDioxide
                       +VolatileAcidity
                       +pH, data = wine, method = 'class')

fancyRpartPlot(WineTreeSTARS)