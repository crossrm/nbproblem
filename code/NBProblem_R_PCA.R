################################################
## PCA N-Body Problem 
################################################

# Libraries
#install.packages("faraway")
#install.packages("MASS")
#install.packages("lars")
#install.packages("pls")
#install.packages("factoextra")
#install.packages("tidyverse")
#install.packages("readr")

# Libraries
library(faraway)
library(MASS)
library(lars)
library(pls)
library(factoextra)
library(tidyverse)
library(readr)

# NB Data
NBdata <- read.csv("C:/data/nbproblem/stagedata/NB_R_PCA_Output.csv", header = TRUE, stringsAsFactors = FALSE, sep = ",")
# View the first few rows of the loaded data
dim(NBdata)

# Prep
str(NBdata)
head(NBdata)
options(digits=3)
p<-ncol(NBdata); p # No. of variables
R<-cor(NBdata); R # Display the correlation matrix

# PCA
NB <- as.data.frame(NBdata)
rates.pca <- prcomp(NBdata,center = TRUE,scale. = TRUE)
names(rates.pca)
print(rates.pca)
summary(rates.pca)
fviz_eig(rates.pca) # Visualization of variance explained by each component

# Variable plot
fviz_pca_var(rates.pca,
             col.var = "contrib", # Control variable color using their contributions to the PC
             gradient.cols = c("#70f6ff", "#00AFBB", "#ffd224", "#d8ac00", "#FC4E07", "#a73203"),
             repel = TRUE,     # Avoid text overlapping
             ggtheme = theme_minimal()
)

##################################
## Example
##################################
# Data
data("USArrests")
dim(USArrests)

# Prep
str(USArrests)
head(USArrests)
options(digits=3)
p<-ncol(USArrests); p # No. of variables
R<-cor(USArrests); R # Display the correlation matrix

# PCA
USArrests <- as.data.frame(USArrests)
arrests.pca <- prcomp(USArrests,center = TRUE,scale. = TRUE)
names(arrests.pca)
print(arrests.pca)
summary(arrests.pca)
fviz_eig(arrests.pca) # Visualization of variance explained by each component

# Variable plot
fviz_pca_var(arrests.pca,
             col.var = "contrib", # Control variable color using their contributions to the PC
             gradient.cols = c("#70f6ff", "#00AFBB", "#ffd224", "#d8ac00", "#FC4E07", "#a73203"),
             repel = TRUE,     # Avoid text overlapping
             ggtheme = theme_minimal()
)
