# Intruções

O modelo de IA deve seguir todas as instruções nesse arquivo para fazer a geração de código desse projeto!

## Arquitetura

Devido o projeto ser para uso pessoal e ser uma MVP, não quero complexidade, então escolho usar o padrão MVVM que já
permite ter um certo nivel de organização dentro do código.

## Método de desenvolvimento

Com a intenção de criar um app sólido e sem bugs em produção (ou o menor possivel), escolhi desenvolver usando TDD.

## Libs base para o projeto

Injetor de dependencia: Get_It
Navegação: Go_Router
Gestão de estado: ChangeNotifier
Banco de dados: SQLite (Offline) e Firebase (Online)
Auth: Google

## Regras dos dados

Todo o app será offline first, armazenando os dados local e subindo os dados quando puder

## Regras para geração de código

SEMPRE VALIDE O CÓDIGO GERADO PARA BUSCAR POSSIVEIS FALHAS DE LÓGICA
SEMPRE DEVE CRIAR O CÓDIGO COM A VISÃO DE UM DEV SÊNIOR, MITIGANDO POSSIVEIS FALHAS
