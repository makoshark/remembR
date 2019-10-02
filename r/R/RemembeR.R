remembr.file <<- "remembr.RDS"
remembr.file.lock <<- paste0(remembr.file,"_LOCK")
remembr.prefix  <<- ""

remembr <- function(var,name,lock=T){

    if(exists("r") == FALSE){
        if(file.exists(remembr.file)){
            lck  <- lock(remembr.file.lock, exclusive = FALSE)
            r <<- readRDS(remembr.file)
            unlock(lck)
        } else {
            r <<- list()
        }
    }

    if(remembr.prefix == ""){
        r[[name]] <<- var
    } else {
        if(is.null(r[[remembr.prefix]])){
            r[[remembr.prefix]]  <<- list()
        }
        r[[remembr.prefix]][[name]]  <<- var
    }

    save_remembr()
}

save_remembr <- function(lock=T){
    lck  <- lock(remembr.file.lock,exclusive=TRUE)
    saveRDS(r,file=remembr.file)
    unlock(lck)
}
