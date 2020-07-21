library(filelock)

remember.file <<- "remembr.RDS"
init.file.lock <- function(){
    remember.file.lock <<- paste0(remember.file,"_LOCK")
}

remember.prefix  <<- ""

change.remember.file <- function(file){
    remember.file <<- file
    init.file.lock()
    save.remember()
}

set.remember.prefix <- function(prefix){
    remember.prefix <<- prefix
}

remember <- function(var,name,lock=T){

    if(exists("r") == FALSE){
        if(file.exists(remember.file)){
            if(!exists("remember.file.lock"))
                init.file.lock()
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

    save_remember()
}

save_remember <- function(lock=T){
    if(!exists("remember.file.lock"))
        init.file.lock()
    
    lck  <- lock(remember.file.lock, exclusive=TRUE)
    saveRDS(r,file=remember.file)
    unlock(lck)
}
