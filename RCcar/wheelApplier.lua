local RC = require("RCcar.RCmain")

RC:registerWheel(models.RCcar.model.root.Wheel.FL,4,false,45)
RC:registerWheel(models.RCcar.model.root.Wheel.FR,4,false,45)
RC:registerWheel(models.RCcar.model.root.Wheel.BL,5,true)
RC:registerWheel(models.RCcar.model.root.Wheel.BR,5,true)