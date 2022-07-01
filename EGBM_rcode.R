install.packages("readxl")
library(readxl)

dat1 <- read_excel("D:/연구/인공지능/Generalizable model/Preprocessing/egbm_input1.xlsx")
dat2 <- read_excel("D:/연구/인공지능/Generalizable model/Preprocessing/egbm_input2.xlsx")
dat3 <- read_excel("D:/연구/인공지능/Generalizable model/Preprocessing/egbm_input3.xlsx")
dat4 <- read_excel("D:/연구/인공지능/Generalizable model/Preprocessing/egbm_input4.xlsx")
dat5 <- read_excel("D:/연구/인공지능/Generalizable model/Preprocessing/egbm_input5.xlsx")
dat6 <- read_excel("D:/연구/인공지능/Generalizable model/Preprocessing/egbm_input6.xlsx")

dat <- rbind(dat1,dat2,dat3,dat4,dat5,dat6)

names(dat) <- c("id", "var1", "study_drug", "var2")


library("tidyr")
library("openEBGM")


processRaw(dat) %>% head(3)

proc <- processRaw(dat)

squashed <- squashData(proc)
squashed <- squashData(squashed, count = 2, bin_size = 10)
head(squashed, 3); tail(squashed, 2)

theta_init1 <- c(alpha1 = 0.2, beta1 = 0.1, alpha2 = 2, beta2 = 4, p = 1/3)
stats::nlminb(start = theta_init1, objective = negLLsquash,
              ni = squashed$N, ei = squashed$E, wi = squashed$weight)$par


qn <- Qn(theta_init1, N = proc$N, E = proc$E)
proc$EBGM <- ebgm(theta_init1, N = proc$N, E = proc$E, qn = qn)
proc$QUANT_025 <- quantBisect(2.5, theta_hat = theta_init1,
                             N = proc$N, E = proc$E, qn = qn)
proc$QUANT_975 <- quantBisect(97.5, theta_hat = theta_init1,
                             N = proc$N, E = proc$E, qn = qn)

write.csv(proc, 'D:/연구/인공지능/Generalizable model/Preprocessing/egbm.csv')




