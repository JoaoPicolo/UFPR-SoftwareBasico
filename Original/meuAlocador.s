.section .data
    topoInicialHeap: .quad 0
    inicioHeap:      .quad 0
    topoHeap:        .quad 0
    TAM_HEADER:      .quad 16
    TAM_BLOCO:       .quad 4096
.section .text
.globl iniciaAlocador
.globl finalizaAlocador
.globl liberaMem
.globl alocaMem
.globl imprimeMapa

# INICIA ALOCADOR
iniciaAlocador:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp

    movq $12, %rax                   # Indica brk
    movq $0, %rdi                    # %rdi contém o novo valor de brk (se zero retorna o valor atual de brk em %rax)
    syscall
    movq %rax, topoInicialHeap
    movq %rax, inicioHeap
    movq %rax, topoHeap

    popq %rbp                        # Retorna funcao
    ret


# FINALIZA ALOCADOR
finalizaAlocador:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    
    movq $12, %rax                   # Indica brk
    movq topoInicialHeap, %rdi       # Restaura para o valor inicial
    syscall
    
    popq %rbp                        # Retorna funcao
    ret


# LIBERA MEMORIA
liberaMem:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    movq %rdi, %rbx                  # %rdi guarda o primeiro parametro da funcao (endereco a ser liberado)

    subq TAM_HEADER, %rbx            # Faz endereco passado apontar para o primeiro byte (flag de ocupado)
    movq $0, (%rbx)                  # Marca bloco como livre

    popq %rbp                        # Retorna funcao
    ret


# ALOCA MEMORIA
alocaMem:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    movq %rdi, %rbx                  # %rdi guarda o primeiro parametro da funcao (tamanho do bloco a ser alocado)

    call bestFit                     # Valor do bloco ja esta em %rdi, por isso so chama funcao
    cmpq $-1, %rax
    je alocaBloco                    # Se nao encontrou opcao, aloca bloco

    movq 8(%rax), %r10               # %r10 := Tamanho do bloco selecionado
    cmpq %rbx, %r10                  # Se bloco escolhido for maior do que necessario, divide ele em dois
    jg divideBlocoSelecionado

    movq $1, (%rax)                  # Atualiza informacoes do bloco
    movq %rbx, 8(%rax)
    jmp fimAlocaMem

    divideBlocoSelecionado:
    movq $1, (%rax)                  # Atualiza informacoes do bloco selecionado
    movq 8(%rax), %r15
    movq %rbx, 8(%rax)
    movq %rax, %r11                  # %r11 = Endereco onde foi alocado + TAM_HEADER + Tamanho alocado     
    addq TAM_HEADER, %r11       
    addq %rbx, %r11

    movq %r10, %rsi
    subq %rbx, %rsi
    cmpq TAM_HEADER, %rsi
    jl restauraBloco
    jmp segmenta

    restauraBloco:
    movq %r15, 8(%rax)
    jmp fimAlocaMem

    segmenta:
    movq $0, (%r11)                  # Marca novo bloco como livre
    subq %rbx, %r10                  # %r10 := Tamanho original do bloco - Tamanho alocado
    subq TAM_HEADER, %r10            # %r10 recebe o tamanho restante depois das informacoes gerenciais
    movq %r10, 8(%r11)
    jmp fimAlocaMem

    alocaBloco:
    call alocaNovoBloco

    fimAlocaMem:
    addq TAM_HEADER, %rax            # %rax := Endereco onde foi alocado + TAM_HEADER (retorno da funcao)
    popq %rbp                        # Retorna funcao
    ret


alocaNovoBloco:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp

    movq TAM_BLOCO, %r13
    addq TAM_HEADER, %rbx            # Garantir que teremos espaco para as infos. gerenciais
    initWhileAloca:
    cmpq %rbx, %r13                  # Se %r13 eh maior ou igual ao necessario, simplesmente aloca
    jge fimWhileAloca                # Se nao, incremente o tamanho do bloco
    addq TAM_BLOCO, %r13
    jmp initWhileAloca

    fimWhileAloca:
    subq TAM_HEADER, %rbx            # Retorna %rbx para o valor real das informacoes (sem considerar as infos. gerenciais)
    movq %r13, %rdi                  # Calcula em %rdi quanto deve ser alocado
    addq topoHeap, %rdi
    movq $12, %rax                   # Aumenta heap chamando syscall para brk
    syscall

    movq topoHeap, %rax
    movq $1, (%rax)                  # Atualiza informacoes do bloco
    movq %rbx, 8(%rax)

    movq 8(%rax), %r10               # %r10 := Tamanho do novo bloco
    cmpq %r10, %r13                  # Se bloco alocado for maior do que o necessario, divide ele em dois
    jg divideNovoBloco
    jmp atualizaInformacoes

    divideNovoBloco:
    movq %rax, %r11                  # %r11 = Endereco onde foi alocado + TAM_HEADER + Tamanho alocado
    addq TAM_HEADER, %r11       
    addq %r10, %r11

    movq %rax, %r12                  # %r12 = antigo topo heap + tamanho do novo bloco
    addq %r13, %r12
    subq %r11, %r12                  # Verifica se tenho espaço no mínimo para as infos. gerenciais + 1 byte
    cmpq TAM_HEADER, %r12
    jle reduzBrk

    movq $0, (%r11)                  # Marca novo bloco como livre
    movq %r13, %r12                  # %r12 := Tamanho do bloco alocado - Tamanho necessario - Infos gerenciais do necessario
    subq %r10, %r12                  
    subq TAM_HEADER, %r12
    subq TAM_HEADER, %r12            # Retira de %r12 suas proprias informacoes gerenciais
    movq %r12, 8(%r11)
    movq $0, %r12
    jmp atualizaInformacoes

    reduzBrk:
    movq %r11, %rdi
    movq $12, %rax
    syscall

    atualizaInformacoes:
    subq %r12, %r13                  # Coloca em %r13 o valor do tamanho do bloco utilizado, sendo ele atualizado (reduzido) ou não
    movq topoHeap, %rax
    movq %rax, %r12                  # Atualiza topo da heap
    addq %r13, %r12
    movq %r12, topoHeap

    popq %rbp                        # Retorna funcao
    ret


bestFit:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    movq %rdi, %rcx                  # %rdi guarda o primeiro parametro da funcao (tamanho do bloco requisitado)

    movq topoInicialHeap, %r12       # %r12 := Inicio heap (nao alterado pelas alocacoes)
    movq topoHeap, %r13
    movq $-1, %r10                   # %r10 mostra a melhor escolha, -1 para nenhum

    initWhileBestFit:
    cmpq %r13, %r12
    jge fimWhileBestFit

    movq (%r12), %r14                # %r14 := Flag do bloco
    cmpq $1, %r14                    # Se o bloco estiver ocupado, vai pro proximo
    je proximoBlocoBest

    movq 8(%r12), %r15               # %r15 := Tamanho do bloco
    cmpq %rcx, %r15                  # Se o bloco for menos do que o requisitado, vai pro proximo
    jl proximoBlocoBest

    cmpq $-1, %r10                   # Se ja existe bloco definido, verifica se vale mudar
    jne verificaMelhor               # Se nao, define como novo
    movq %r12, %r10
    jmp proximoBlocoBest

    verificaMelhor:
    cmpq 8(%r10), %r15               # Se tamanho for maior ou igual ao melhor do momento, vai pro proximo
    jge proximoBlocoBest
    movq %r12, %r10

    proximoBlocoBest:
    addq 8(%r12), %r12               # Calcula proximo bloco
    addq TAM_HEADER, %r12            
    jmp initWhileBestFit 

    fimWhileBestFit:
    movq %r10, %rax                  # %rax := Inicio do bloco da melhor opcao
    popq %rbp                        # Retorna funcao
    ret

firstFit:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    movq %rdi, %rcx                  # %rdi guarda o primeiro parametro da funcao (tamanho do bloco requisitado)

    movq topoInicialHeap, %r12       # %r12 := Inicio heap (nao alterado pelas alocacoes)
    movq topoHeap, %r13
    movq $-1, %r10                   # %r10 mostra a melhor escolha, -1 para nenhum

    initWhileFirstFit:
    cmpq %r13, %r12
    jge fimWhileFirstFit

    movq (%r12), %r14                # %r14 := Flag do bloco
    cmpq $1, %r14                    # Se o bloco estiver ocupado, vai pro proximo
    je proximoBlocoFirst

    movq 8(%r12), %r15               # %r15 := Tamanho do bloco
    cmpq %rcx, %r15                  # Se o bloco for menos do que o requisitado, vai pro proximo
    jl proximoBlocoFirst

    movq %r12, %r10                  # Coloca o valor do primeiro bloco que cabe em %r10 e sai do loop
    jmp fimWhileFirstFit

    proximoBlocoFirst:
    addq 8(%r12), %r12               # Calcula proximo bloco
    addq TAM_HEADER, %r12            
    jmp initWhileFirstFit 

    fimWhileFirstFit:
    movq %r10, %rax                  # %rax := Inicio do bloco da melhor opcao
    popq %rbp                        # Retorna funcao
    ret


nextFit:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    movq %rdi, %rcx                  # %rdi guarda o primeiro parametro da funcao (tamanho do bloco requisitado)

    movq proxPesquisa, %r12          # %r12 := Proximo endereco a comecar a pesquisa (nao alterado pelas alocacoes)
    movq topoHeap, %r13
    movq proxPesquisa, %r11          # %r11 := Endereco inicial de onde comecou
    movq $-1, %r10                   # %r10 mostra a melhor escolha, -1 para nenhum

    initWhileNextFit:
    cmpq %r13, %r12
    je atualizaProximo

    movq (%r12), %r14                # %r14 := Flag do bloco
    cmpq $1, %r14                    # Se o bloco estiver ocupado, vai pro proximo
    je proximoBlocoNext

    movq 8(%r12), %r15               # %r15 := Tamanho do bloco
    cmpq %rcx, %r15                  # Se o bloco for menos do que o requisitado, vai pro proximo
    jl proximoBlocoNext

    movq %r12, %r10                  # Coloca o valor do primeiro bloco que cabe em %r10
    addq 8(%r12), %r12               # Calcula proximo bloco
    addq TAM_HEADER, %r12
    movq %r12, proxPesquisa          # Atualiza endereco de onde comecar proxima pesquisa  
    jmp fimWhileNextFit

    proximoBlocoNext:
    addq 8(%r12), %r12               # Calcula proximo bloco
    addq TAM_HEADER, %r12     
    cmpq %r12, %r11                  # Verifica se a lista circulou (se o proximo eh onde fizemos a primeira pesquisa)
    je pesquisaCirculou
    jmp initWhileNextFit

    pesquisaCirculou:
    movq %r12, proxPesquisa
    jmp fimWhileNextFit

    atualizaProximo:                 
    cmpq topoInicialHeap, %r13       # Se nao tem nada alocado na heap, retorna    
    je fimWhileNextFit
    
    movq inicioHeap, %rdi
    movq %rdi, proxPesquisa
    movq %rdi, %r12
    jmp initWhileNextFit

    fimWhileNextFit:
    movq %r10, %rax                  # %rax := Inicio do bloco da melhor opcao
    popq %rbp                        # Retorna funcao
    ret


# IMPRIME MAPA
imprimeMapa:
    pushq %rbp                       # Empilha informacoes da funcao
    movq %rsp, %rbp
    movq inicioHeap, %r12            # Endereco do inicio da heap
    movq topoHeap, %r13              # Endereco do topo da heap
    
    initWhileImprime:
    cmpq %r13, %r12
    jge fimWhileImprime
    call imprimeHeader
    
    movq (%r12), %r10                # %r10 := Conteudo de %r12 (flag de ocupado)
    movq 8(%r12), %r11               # %r11 := Conteudo de %r12 + 8 bytes (tamanho do bloco)
    cmpq $1, %r10
    je imprimeOcupado
    
    movq %r11, %rdi                  # %rdi eh o primeiro parametro da funcao seguinte
    call imprimeBlocoLivre           # Imprime bytes do bloco livre
    jmp incrementaAtual

    imprimeOcupado:
    movq %r11, %rdi                  # %rdi eh o primeiro parametro da funcao seguinte
    call imprimeBlocoOcupado         # Imprime bytes do bloco ocupado

    incrementaAtual:             
    addq 8(%r12), %r12               # Aumenta o endereco apontado pelo inicio da heap
    addq TAM_HEADER, %r12            
    jmp initWhileImprime          

    fimWhileImprime:
    movq $10, %rdi                   # 10 igual a \n em ascii
    call putchar
    movq $10, %rdi
    call putchar
    popq %rbp                        # Retorna funcao
    ret


imprimeHeader:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %r14 		             # Inicializa contador
    initWhileHeader:
    cmpq TAM_HEADER, %r14
    jge fimWhileHeader
    movq $35, %rdi                   # 35 igual a # em ascii
    call putchar
    addq $1, %r14
    jmp initWhileHeader
    fimWhileHeader:
    popq %rbp
    ret


imprimeBlocoOcupado:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rbx                  # %rbx := Tamanho do bloco (1o parametro passado)
    movq $0, %r14 		             # Inicializa contador
    initWhileOcupado:
    cmpq %rbx, %r14
    jge fimWhileOcupado
    movq $43, %rdi                   # 43 igual a + em ascii
    call putchar
    addq $1, %r14
    jmp initWhileOcupado
    fimWhileOcupado:
    popq %rbp
    ret


imprimeBlocoLivre:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rbx                  # %rbx := Tamanho do bloco (1o parametro passado)
    movq $0, %r14 		             # Inicializa contador
    initWhileLivre:
    cmpq %rbx, %r14
    jge fimWhileLivre
    movq $45, %rdi                   # 45 igual a - em ascii
    call putchar
    addq $1, %r14
    jmp initWhileLivre
    fimWhileLivre:
    popq %rbp
    ret
