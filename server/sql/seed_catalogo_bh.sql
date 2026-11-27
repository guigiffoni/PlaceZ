-- Catálogo real curado da região metropolitana de Belo Horizonte.
-- Coordenadas aproximadas, adequadas para demonstração e cálculo de distância.
-- Pode ser executado novamente: regiões são mescladas e o catálogo é recriado.

MERGE INTO regiao_aproximada d
USING (
  SELECT 'Centro' nome, 'Belo Horizonte' cidade, -19.9245 latitude, -43.9400 longitude FROM dual
  UNION ALL SELECT 'Savassi', 'Belo Horizonte', -19.9380, -43.9330 FROM dual
  UNION ALL SELECT 'Lourdes', 'Belo Horizonte', -19.9300, -43.9420 FROM dual
  UNION ALL SELECT 'Santa Tereza', 'Belo Horizonte', -19.9160, -43.9240 FROM dual
  UNION ALL SELECT 'Pampulha', 'Belo Horizonte', -19.8600, -43.9700 FROM dual
  UNION ALL SELECT 'Cidade Jardim', 'Belo Horizonte', -19.9300, -43.9550 FROM dual
  UNION ALL SELECT 'Belvedere', 'Belo Horizonte', -19.9720, -43.9470 FROM dual
  UNION ALL SELECT 'Venda Nova', 'Belo Horizonte', -19.8700, -43.9200 FROM dual
  UNION ALL SELECT 'Barreiro', 'Belo Horizonte', -20.0200, -44.0000 FROM dual
  UNION ALL SELECT 'Contagem', 'Contagem', -19.9320, -44.0530 FROM dual
  UNION ALL SELECT 'Betim', 'Betim', -19.9680, -44.1980 FROM dual
  UNION ALL SELECT 'Nova Lima', 'Nova Lima', -19.9850, -43.8460 FROM dual
  UNION ALL SELECT 'Santa Luzia', 'Santa Luzia', -19.7690, -43.8510 FROM dual
  UNION ALL SELECT 'Ribeirão das Neves', 'Ribeirão das Neves', -19.7670, -44.0870 FROM dual
  UNION ALL SELECT 'Vespasiano', 'Vespasiano', -19.6920, -43.9230 FROM dual
  UNION ALL SELECT 'Lagoa Santa', 'Lagoa Santa', -19.6300, -43.8900 FROM dual
  UNION ALL SELECT 'Sabará', 'Sabará', -19.8870, -43.8070 FROM dual
  UNION ALL SELECT 'Ibirité', 'Ibirité', -20.0220, -44.0580 FROM dual
  UNION ALL SELECT 'Pedro Leopoldo', 'Pedro Leopoldo', -19.6180, -44.0430 FROM dual
  UNION ALL SELECT 'Brumadinho', 'Brumadinho', -20.1430, -44.2000 FROM dual
) s
ON (d.nome = s.nome AND d.cidade = s.cidade)
WHEN NOT MATCHED THEN
  INSERT (nome, cidade, latitude, longitude)
  VALUES (s.nome, s.cidade, s.latitude, s.longitude);

DELETE FROM catalogo_lugar;

INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Mercado Central de Belo Horizonte', 'Av. Augusto de Lima, 744 - Centro', 'Mercado', 'Belo Horizonte', -19.9245, -43.9420);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Mercado Novo', 'Av. Oiapoque, 200 - Centro', 'Mercado', 'Belo Horizonte', -19.9248, -43.9438);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Sete de Setembro', 'Av. Afonso Pena com Rua Rio de Janeiro - Centro', 'Praça', 'Belo Horizonte', -19.9191, -43.9386);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça da Liberdade', 'Av. Bias Fortes - Funcionários', 'Praça', 'Belo Horizonte', -19.9316, -43.9380);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça da Savassi', 'Rua Pernambuco - Savassi', 'Praça', 'Belo Horizonte', -19.9384, -43.9336);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Parque Municipal Américo Renné Giannetti', 'Av. Afonso Pena, 1377 - Centro', 'Parque', 'Belo Horizonte', -19.9238, -43.9350);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Palácio das Artes', 'Av. Afonso Pena, 1537 - Centro', 'Teatro', 'Belo Horizonte', -19.9230, -43.9373);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Museu de Arte da Pampulha', 'Av. Otacílio Negrão de Lima, 16585 - Pampulha', 'Museu', 'Belo Horizonte', -19.8550, -43.9670);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Lagoa da Pampulha', 'Av. Otacílio Negrão de Lima - Pampulha', 'Parque', 'Belo Horizonte', -19.8555, -43.9690);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Mineirão', 'Av. Antônio Abrahão Caram, 1001 - Pampulha', 'Estádio', 'Belo Horizonte', -19.8659, -43.9712);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Mirante do Mangabeiras', 'Av. Agulhas Negras - Mangabeiras', 'Mirante', 'Belo Horizonte', -19.9450, -43.9330);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Casa do Baile', 'Av. Otacílio Negrão de Lima, 751 - Pampulha', 'Centro Cultural', 'Belo Horizonte', -19.8570, -43.9720);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Duque de Caxias', 'Rua Estêvão Pinto - Santa Tereza', 'Praça', 'Belo Horizonte', -19.9160, -43.9240);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Museu Histórico Abílio Barreto', 'Av. Prudente de Morais, 202 - Cidade Jardim', 'Museu', 'Belo Horizonte', -19.9300, -43.9550);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('BH Shopping', 'BR-356, 3049 - Belvedere', 'Shopping', 'Belo Horizonte', -19.9720, -43.9470);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Shopping Estação BH', 'Av. Cristiano Machado, 11833 - Cidade Nova', 'Shopping', 'Belo Horizonte', -19.9030, -43.9260);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Minas Shopping', 'Av. Cristiano Machado, 4000 - União', 'Shopping', 'Belo Horizonte', -19.8970, -43.9250);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Museu de Artes e Ofícios', 'Praça Rui Barbosa, 600 - Centro', 'Museu', 'Belo Horizonte', -19.9170, -43.9340);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Café Palhares', 'Rua Rio de Janeiro, 762 - Centro', 'Café', 'Belo Horizonte', -19.9220, -43.9380);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Restaurante Xapuri', 'Rua Mandacaru, 260 - Pampulha', 'Restaurante', 'Belo Horizonte', -19.8700, -43.9700);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Parque Guanabara', 'Av. Presidente Antônio Carlos, 6667 - Pampulha', 'Parque', 'Belo Horizonte', -19.8870, -43.9500);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça da Assembleia', 'Rua Rodrigues Caldas, 30 - Santo Agostinho', 'Praça', 'Belo Horizonte', -19.9300, -43.9450);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça do Papa', 'Av. Agulhas Negras - Mangabeiras', 'Mirante', 'Belo Horizonte', -19.9380, -43.9330);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Cine Theatro Brasil Vallourec', 'Av. Amazonas, 315 - Centro', 'Teatro', 'Belo Horizonte', -19.9200, -43.9400);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Feira Hippie da Afonso Pena', 'Av. Afonso Pena - Centro', 'Feira', 'Belo Horizonte', -19.9220, -43.9360);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Inhotim', 'Rua B, 20 - Brumadinho', 'Museu', 'Brumadinho', -20.1240, -44.2180);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Bernardino de Lima', 'Centro - Nova Lima', 'Praça', 'Nova Lima', -19.9850, -43.8460);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Tancredo Neves', 'Centro - Contagem', 'Praça', 'Contagem', -19.9320, -44.0530);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Monte Carmo Shopping', 'Av. Monte Carmelo, 100 - Betim', 'Shopping', 'Betim', -19.9680, -44.1980);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Lagoa Central de Lagoa Santa', 'Centro - Lagoa Santa', 'Parque', 'Lagoa Santa', -19.6300, -43.8900);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Gruta da Lapinha', 'Lagoa Santa', 'Parque', 'Lagoa Santa', -19.6100, -43.9000);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Getúlio Vargas', 'Centro - Sabará', 'Praça', 'Sabará', -19.8870, -43.8070);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça da Matriz', 'Centro - Vespasiano', 'Praça', 'Vespasiano', -19.6920, -43.9230);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Central de Ribeirão das Neves', 'Centro - Ribeirão das Neves', 'Praça', 'Ribeirão das Neves', -19.7670, -44.0870);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Parque Ecológico de Ibirité', 'Ibirité', 'Parque', 'Ibirité', -20.0220, -44.0580);
INSERT INTO catalogo_lugar (nome, endereco, categoria, cidade, latitude, longitude)
VALUES ('Praça Afonso Pena', 'Centro - Santa Luzia', 'Praça', 'Santa Luzia', -19.7690, -43.8510);

COMMIT;
