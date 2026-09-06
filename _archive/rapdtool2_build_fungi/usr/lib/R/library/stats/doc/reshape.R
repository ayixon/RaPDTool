### R code from vignette source 'reshape.Rnw'

###################################################
### code chunk number 1: reshape.Rnw:23-26
###################################################
library(stats)
options(width = 80, continue = "  ",
        try.outFile = stdout())


###################################################
### code chunk number 2: reshape.Rnw:58-66
###################################################
set.seed(12345)
n <- 5
d1 <- data.frame(sex = sample(c("M", "F"), n, rep = TRUE),
                 ht.before = round(rnorm(n, 165, 6), 1),
                 ht.after = round(rnorm(n, 165, 6), 1),
                 wt.before = round(rnorm(n, 80, 6)),
                 wt.after = round(rnorm(n, 80, 6)))
d1


###################################################
### code chunk number 3: reshape.Rnw:88-90
###################################################
reshape(d1, direction = "long",
        varying = c("ht.before", "ht.after"))


###################################################
### code chunk number 4: reshape.Rnw:95-97
###################################################
reshape(d1, direction = "long",
        varying = c(2, 3))


###################################################
### code chunk number 5: reshape.Rnw:104-110
###################################################
n <- 5
d2 <- data.frame(sex = sample(c("M", "F"), n, rep = TRUE),
                 ht_before = round(rnorm(n, 165, 6), 1),
                 ht_after = round(rnorm(n, 165, 6), 1),
                 wt_before = round(rnorm(n, 80, 6)),
                 wt_after = round(rnorm(n, 80, 6)))


###################################################
### code chunk number 6: reshape.Rnw:117-121
###################################################
try(
reshape(d2, direction = "long",
        varying = c("wt_before", "wt_after")),
)


###################################################
### code chunk number 7: reshape.Rnw:128-130
###################################################
reshape(d2, direction = "long",
        varying = c("wt_before", "wt_after"), sep = "_")


###################################################
### code chunk number 8: reshape.Rnw:136-139
###################################################
reshape(d2, direction = "long",
        varying = c("wt_before", "wt_after"),
        v.names = "weight") 


###################################################
### code chunk number 9: reshape.Rnw:145-150
###################################################
reshape(d2, direction = "long",
        varying = c("wt_before", "wt_after"),
        v.names = "weight", 
        timevar = "when", times = c("pre", "post"),
        idvar = "subject", ids = letters[1:n])


###################################################
### code chunk number 10: reshape.Rnw:156-160
###################################################
reshape(d2, direction = "long",
        varying = c("wt_before", "wt_after"), sep = "_",
        ## v.names = "wt", # without this, 'times' is unused 
        timevar = "when", times = c("pre", "post"))


###################################################
### code chunk number 11: reshape.Rnw:178-188
###################################################
reshape(d2, direction = "long",
        varying = list(c("ht_before", "ht_after"),
                       c("wt_before", "wt_after")), # list form
        v.names = c("height", "weight"),
        times = c("pre", "post"))

reshape(d2, direction = "long",
        varying = rbind(c("ht_before", "ht_after"),
                        c("wt_before", "wt_after")), # matrix form
        v.names = c("height", "weight"))


###################################################
### code chunk number 12: reshape.Rnw:199-207
###################################################
reshape(d2, direction = "long",
        varying = rbind(c("ht_before", "ht_after"),
                        c("wt_before", "wt_after")),
        v.names = c("height", "weight"),
        timevar = "when",
        times = c("pre", "post"),
        idvar = "subject",
        ids = letters[1:n])


###################################################
### code chunk number 13: reshape.Rnw:223-226
###################################################
reshape(d2, direction = "long",
        varying = c("ht_before", "ht_after",
                    "wt_before", "wt_after"), sep = "_")


###################################################
### code chunk number 14: reshape.Rnw:235-239
###################################################
reshape(d2, direction = "long",
        varying = c("ht_before", "ht_after",
                    "wt_before", "wt_after"),
        v.names = c("height", "weight"))


###################################################
### code chunk number 15: reshape.Rnw:247-251 (eval = FALSE)
###################################################
## reshape(d2, direction = "long",
##         varying = c("ht_before", "wt_before",
##                     "ht_after", "wt_after"),
##         v.names = c("height", "weight"))


###################################################
### code chunk number 16: reshape.Rnw:261-272
###################################################
dlong <- 
    reshape(d2, direction = "long",
            varying = c("ht_before", "wt_before",
                        "ht_after", "wt_after"),
            v.names = c("height", "weight"),
            timevar = "when", times = c("pre", "post"),
            idvar = "subject", ids = letters[1:n])
reshape(dlong, direction = "long",
        varying = c("height", "weight"),
        v.names = "combined",
        timevar = "what", times = c("height", "weight"))


###################################################
### code chunk number 17: reshape.Rnw:279-285
###################################################
reshape(d2, direction = "long",
        v.names = "combined",
        varying = c("ht_before", "ht_after", "wt_before", "wt_after"),
        timevar = "when_what",
        times = c("pre_height", "post_height", "pre_weight", "post_weight"),
        idvar = "subject", ids = letters[1:n])


###################################################
### code chunk number 18: reshape.Rnw:294-300
###################################################
d3 <- data.frame(sex = sample(c("M", "F"), 2 * n, rep = TRUE),
                 ht = round(rnorm(2 * n, 165, 6), 1),
                 wt = round(rnorm(2 * n, 80, 6)),
                 subject = rep(1:n, 2),
                 when = rep(c("pre", "post"), each = n))
d3


###################################################
### code chunk number 19: reshape.Rnw:309-311
###################################################
reshape(d3, direction = "wide",
        idvar = "subject", timevar = "when")


###################################################
### code chunk number 20: reshape.Rnw:317-320 (eval = FALSE)
###################################################
## reshape(d3, direction = "wide",
##         idvar = "subject", timevar = "when",
##         v.names = c("ht", "wt"))


###################################################
### code chunk number 21: reshape.Rnw:326-335
###################################################
n <- 10
d4 <- data.frame(sex = rep(sample(c("M", "F"), n, rep = TRUE), 2),
                 ht = round(rnorm(2 * n, 165, 6), 1),
                 wt = round(rnorm(2 * n, 80, 6)),
                 subject = rep(1:n, 2),
                 when = rep(c("pre", "post"), each = n))
reshape(d4, direction = "wide",
        idvar = "subject", timevar = "when",
        v.names = c("ht", "wt"), sep = "_")


###################################################
### code chunk number 22: reshape.Rnw:344-348
###################################################
reshape(d4, direction = "wide",
        idvar = "subject", timevar = "when",
        v.names = c("ht", "wt"),
        varying = c("h_before", "w_before", "h_after", "w_after"))


###################################################
### code chunk number 23: reshape.Rnw:356-361
###################################################
reshape(d4, direction = "wide",
        idvar = "subject", timevar = "when",
        v.names = c("ht", "wt"),
        varying = list(c("h_before", "h_after"),
                       c("w_before", "w_after")))


