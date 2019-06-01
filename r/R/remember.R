remember.file <<- "remember.RDS"
remember.file.lock <<- paste0(remember.file,"_LOCK")
remember.prefix  <<- ""

remember <- function(var,name,lock=T){

    if(exists("r") == FALSE){
        if(file.exists(remember.file)){
            lck  <- lock(remember.file.lock, exclusive = FALSE)
            r <<- readRDS(remember.file)
            unlock(lck)
        } else {
            r <<- list()
        }
    }

    if(remember.prefix == ""){
        r[[name]] <<- var
    } else {
        if(is.null(r[[remember.prefix]])){
            r[[remember.prefix]]  <<- list()
        }
        r[[remember.prefix]][[name]]  <<- var
    }

    save.r()
}

save.r <- function(lock=T){
    lck  <- lock(remember.file.lock,exclusive=TRUE)
    saveRDS(r,file=remember.file)
    unlock(lck)
}
