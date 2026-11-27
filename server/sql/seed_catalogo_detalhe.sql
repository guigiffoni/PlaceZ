-- Detalhes do catálogo real de BH: descrição, preço, itens, avaliações curadas
-- e comentários editoriais. Pode ser executado novamente.
DELETE FROM catalogo_lugar_item;
DELETE FROM catalogo_lugar_avaliacao WHERE usuario_id IS NULL;

UPDATE catalogo_lugar SET
  descricao = 'Tradicional mercado de BH com bancas de comida mineira, temperos, artesanato e produtos frescos.',
  faixa_preco = 'R$ 20–80',
  avaliacao_media = 4.8,
  avaliacao_total = 2450
WHERE nome = 'Mercado Central de Belo Horizonte';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comida mineira', 1 FROM catalogo_lugar WHERE nome = 'Mercado Central de Belo Horizonte';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Queijos e doces', 2 FROM catalogo_lugar WHERE nome = 'Mercado Central de Belo Horizonte';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Artesanato', 3 FROM catalogo_lugar WHERE nome = 'Mercado Central de Belo Horizonte';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Temperos', 4 FROM catalogo_lugar WHERE nome = 'Mercado Central de Belo Horizonte';

UPDATE catalogo_lugar SET
  descricao = 'Galpão urbano com bares, restaurantes, cafés e lojas criativas no centro.',
  faixa_preco = 'R$ 30–120',
  avaliacao_media = 4.7,
  avaliacao_total = 1800
WHERE nome = 'Mercado Novo';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Bares', 1 FROM catalogo_lugar WHERE nome = 'Mercado Novo';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Hambúrgueres', 2 FROM catalogo_lugar WHERE nome = 'Mercado Novo';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cafés', 3 FROM catalogo_lugar WHERE nome = 'Mercado Novo';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lojas criativas', 4 FROM catalogo_lugar WHERE nome = 'Mercado Novo';

UPDATE catalogo_lugar SET
  descricao = 'Marco central de BH, cercado por comércio, bancos e o obelisco da cidade.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.4,
  avaliacao_total = 900
WHERE nome = 'Praça Sete de Setembro';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Obelisco', 1 FROM catalogo_lugar WHERE nome = 'Praça Sete de Setembro';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comércio', 2 FROM catalogo_lugar WHERE nome = 'Praça Sete de Setembro';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Fotografia urbana', 3 FROM catalogo_lugar WHERE nome = 'Praça Sete de Setembro';

UPDATE catalogo_lugar SET
  descricao = 'Praça arborizada no circuito cultural, próxima a museus e prédios históricos.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.8,
  avaliacao_total = 2100
WHERE nome = 'Praça da Liberdade';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Museus', 1 FROM catalogo_lugar WHERE nome = 'Praça da Liberdade';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 2 FROM catalogo_lugar WHERE nome = 'Praça da Liberdade';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Eventos culturais', 3 FROM catalogo_lugar WHERE nome = 'Praça da Liberdade';

UPDATE catalogo_lugar SET
  descricao = 'Ponto de encontro boêmio da Savassi, com bares, cafés e vida noturna.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.5,
  avaliacao_total = 1300
WHERE nome = 'Praça da Savassi';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Bares', 1 FROM catalogo_lugar WHERE nome = 'Praça da Savassi';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cafés', 2 FROM catalogo_lugar WHERE nome = 'Praça da Savassi';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Vida noturna', 3 FROM catalogo_lugar WHERE nome = 'Praça da Savassi';

UPDATE catalogo_lugar SET
  descricao = 'Parque histórico no centro, com lago, trilhas, jardins e área para piquenique.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.6,
  avaliacao_total = 1500
WHERE nome = 'Parque Municipal Américo Renné Giannetti';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lago', 1 FROM catalogo_lugar WHERE nome = 'Parque Municipal Américo Renné Giannetti';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Trilhas', 2 FROM catalogo_lugar WHERE nome = 'Parque Municipal Américo Renné Giannetti';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Piquenique', 3 FROM catalogo_lugar WHERE nome = 'Parque Municipal Américo Renné Giannetti';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 4 FROM catalogo_lugar WHERE nome = 'Parque Municipal Américo Renné Giannetti';

UPDATE catalogo_lugar SET
  descricao = 'Centro cultural com teatro, cinema, galerias e programação musical.',
  faixa_preco = 'R$ 20–80',
  avaliacao_media = 4.8,
  avaliacao_total = 1600
WHERE nome = 'Palácio das Artes';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Teatro', 1 FROM catalogo_lugar WHERE nome = 'Palácio das Artes';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cinema', 2 FROM catalogo_lugar WHERE nome = 'Palácio das Artes';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Galerias', 3 FROM catalogo_lugar WHERE nome = 'Palácio das Artes';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Shows', 4 FROM catalogo_lugar WHERE nome = 'Palácio das Artes';

UPDATE catalogo_lugar SET
  descricao = 'Museu modernista à beira da Lagoa da Pampulha, com acervo de arte brasileira.',
  faixa_preco = 'R$ 10–30',
  avaliacao_media = 4.6,
  avaliacao_total = 700
WHERE nome = 'Museu de Arte da Pampulha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Arte moderna', 1 FROM catalogo_lugar WHERE nome = 'Museu de Arte da Pampulha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Arquitetura', 2 FROM catalogo_lugar WHERE nome = 'Museu de Arte da Pampulha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Exposições', 3 FROM catalogo_lugar WHERE nome = 'Museu de Arte da Pampulha';

UPDATE catalogo_lugar SET
  descricao = 'Cartão-postal de BH, ideal para caminhadas, pedaladas e pôr do sol.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.7,
  avaliacao_total = 1900
WHERE nome = 'Lagoa da Pampulha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Caminhada', 1 FROM catalogo_lugar WHERE nome = 'Lagoa da Pampulha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Pedal', 2 FROM catalogo_lugar WHERE nome = 'Lagoa da Pampulha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Pôr do sol', 3 FROM catalogo_lugar WHERE nome = 'Lagoa da Pampulha';

UPDATE catalogo_lugar SET
  descricao = 'Estádio histórico e moderno, com tour, museu e jogos de futebol.',
  faixa_preco = 'R$ 40–200',
  avaliacao_media = 4.7,
  avaliacao_total = 2200
WHERE nome = 'Mineirão';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Futebol', 1 FROM catalogo_lugar WHERE nome = 'Mineirão';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Tour', 2 FROM catalogo_lugar WHERE nome = 'Mineirão';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Museu do Mineirão', 3 FROM catalogo_lugar WHERE nome = 'Mineirão';

UPDATE catalogo_lugar SET
  descricao = 'Vista panorâmica de BH, ótima para fotos e piquenique.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.6,
  avaliacao_total = 800
WHERE nome = 'Mirante do Mangabeiras';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Vista panorâmica', 1 FROM catalogo_lugar WHERE nome = 'Mirante do Mangabeiras';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Fotos', 2 FROM catalogo_lugar WHERE nome = 'Mirante do Mangabeiras';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Piquenique', 3 FROM catalogo_lugar WHERE nome = 'Mirante do Mangabeiras';

UPDATE catalogo_lugar SET
  descricao = 'Obra de Niemeyer às margens da Lagoa, com exposições e eventos.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.5,
  avaliacao_total = 450
WHERE nome = 'Casa do Baile';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Arquitetura', 1 FROM catalogo_lugar WHERE nome = 'Casa do Baile';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Exposições', 2 FROM catalogo_lugar WHERE nome = 'Casa do Baile';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lagoa', 3 FROM catalogo_lugar WHERE nome = 'Casa do Baile';

UPDATE catalogo_lugar SET
  descricao = 'Praça de Santa Tereza com feiras, bares e o clima boêmio do bairro.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.4,
  avaliacao_total = 300
WHERE nome = 'Praça Duque de Caxias';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Feiras', 1 FROM catalogo_lugar WHERE nome = 'Praça Duque de Caxias';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Bares', 2 FROM catalogo_lugar WHERE nome = 'Praça Duque de Caxias';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Música', 3 FROM catalogo_lugar WHERE nome = 'Praça Duque de Caxias';

UPDATE catalogo_lugar SET
  descricao = 'Museu sobre a história de BH, com casarão histórico e jardins.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.6,
  avaliacao_total = 500
WHERE nome = 'Museu Histórico Abílio Barreto';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'História de BH', 1 FROM catalogo_lugar WHERE nome = 'Museu Histórico Abílio Barreto';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Casarão', 2 FROM catalogo_lugar WHERE nome = 'Museu Histórico Abílio Barreto';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 3 FROM catalogo_lugar WHERE nome = 'Museu Histórico Abílio Barreto';

UPDATE catalogo_lugar SET
  descricao = 'Shopping com lojas, cinema, praça de alimentação e serviços.',
  faixa_preco = 'R$ 30–150',
  avaliacao_media = 4.5,
  avaliacao_total = 2000
WHERE nome = 'BH Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lojas', 1 FROM catalogo_lugar WHERE nome = 'BH Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cinema', 2 FROM catalogo_lugar WHERE nome = 'BH Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Praça de alimentação', 3 FROM catalogo_lugar WHERE nome = 'BH Shopping';

UPDATE catalogo_lugar SET
  descricao = 'Shopping ao lado da estação de metrô, com lojas e alimentação.',
  faixa_preco = 'R$ 25–120',
  avaliacao_media = 4.3,
  avaliacao_total = 1200
WHERE nome = 'Shopping Estação BH';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lojas', 1 FROM catalogo_lugar WHERE nome = 'Shopping Estação BH';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Metrô', 2 FROM catalogo_lugar WHERE nome = 'Shopping Estação BH';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Praça de alimentação', 3 FROM catalogo_lugar WHERE nome = 'Shopping Estação BH';

UPDATE catalogo_lugar SET
  descricao = 'Shopping tradicional da zona norte, com cinema e muitas lojas.',
  faixa_preco = 'R$ 25–120',
  avaliacao_media = 4.4,
  avaliacao_total = 1100
WHERE nome = 'Minas Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lojas', 1 FROM catalogo_lugar WHERE nome = 'Minas Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cinema', 2 FROM catalogo_lugar WHERE nome = 'Minas Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Alimentação', 3 FROM catalogo_lugar WHERE nome = 'Minas Shopping';

UPDATE catalogo_lugar SET
  descricao = 'Museu no antigo prédio da estação ferroviária, dedicado ao trabalho e ofícios.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.7,
  avaliacao_total = 600
WHERE nome = 'Museu de Artes e Ofícios';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Artes e ofícios', 1 FROM catalogo_lugar WHERE nome = 'Museu de Artes e Ofícios';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'História', 2 FROM catalogo_lugar WHERE nome = 'Museu de Artes e Ofícios';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Arquitetura', 3 FROM catalogo_lugar WHERE nome = 'Museu de Artes e Ofícios';

UPDATE catalogo_lugar SET
  descricao = 'Café tradicional do centro, famoso pelo café coado e pelo clima simples.',
  faixa_preco = 'R$ 10–30',
  avaliacao_media = 4.6,
  avaliacao_total = 900
WHERE nome = 'Café Palhares';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Café coado', 1 FROM catalogo_lugar WHERE nome = 'Café Palhares';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Pão de queijo', 2 FROM catalogo_lugar WHERE nome = 'Café Palhares';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Salgados', 3 FROM catalogo_lugar WHERE nome = 'Café Palhares';

UPDATE catalogo_lugar SET
  descricao = 'Restaurante de comida mineira no estilo fazenda, com pratos tradicionais.',
  faixa_preco = 'R$ 60–140',
  avaliacao_media = 4.8,
  avaliacao_total = 1300
WHERE nome = 'Restaurante Xapuri';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comida mineira', 1 FROM catalogo_lugar WHERE nome = 'Restaurante Xapuri';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Feijão tropeiro', 2 FROM catalogo_lugar WHERE nome = 'Restaurante Xapuri';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Frango com quiabo', 3 FROM catalogo_lugar WHERE nome = 'Restaurante Xapuri';

UPDATE catalogo_lugar SET
  descricao = 'Parque de diversões tradicional de BH, com brinquedos e áreas verdes.',
  faixa_preco = 'R$ 20–80',
  avaliacao_media = 4.5,
  avaliacao_total = 1000
WHERE nome = 'Parque Guanabara';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Brinquedos', 1 FROM catalogo_lugar WHERE nome = 'Parque Guanabara';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Áreas verdes', 2 FROM catalogo_lugar WHERE nome = 'Parque Guanabara';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Família', 3 FROM catalogo_lugar WHERE nome = 'Parque Guanabara';

UPDATE catalogo_lugar SET
  descricao = 'Praça tranquila em frente à Assembleia, com jardins e monumentos.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.4,
  avaliacao_total = 250
WHERE nome = 'Praça da Assembleia';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 1 FROM catalogo_lugar WHERE nome = 'Praça da Assembleia';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Monumentos', 2 FROM catalogo_lugar WHERE nome = 'Praça da Assembleia';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Caminhada', 3 FROM catalogo_lugar WHERE nome = 'Praça da Assembleia';

UPDATE catalogo_lugar SET
  descricao = 'Mirante com vista ampla de BH, palco de eventos e encontros.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.7,
  avaliacao_total = 1200
WHERE nome = 'Praça do Papa';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Vista', 1 FROM catalogo_lugar WHERE nome = 'Praça do Papa';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Eventos', 2 FROM catalogo_lugar WHERE nome = 'Praça do Papa';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Pôr do sol', 3 FROM catalogo_lugar WHERE nome = 'Praça do Papa';

UPDATE catalogo_lugar SET
  descricao = 'Teatro e cinema histórico restaurado no centro, com programação cultural.',
  faixa_preco = 'R$ 20–60',
  avaliacao_media = 4.7,
  avaliacao_total = 800
WHERE nome = 'Cine Theatro Brasil Vallourec';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Teatro', 1 FROM catalogo_lugar WHERE nome = 'Cine Theatro Brasil Vallourec';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cinema', 2 FROM catalogo_lugar WHERE nome = 'Cine Theatro Brasil Vallourec';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Shows', 3 FROM catalogo_lugar WHERE nome = 'Cine Theatro Brasil Vallourec';

UPDATE catalogo_lugar SET
  descricao = 'Feira de artesanato, roupas, comidas e presentes na Afonso Pena.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.6,
  avaliacao_total = 1100
WHERE nome = 'Feira Hippie da Afonso Pena';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Artesanato', 1 FROM catalogo_lugar WHERE nome = 'Feira Hippie da Afonso Pena';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Roupas', 2 FROM catalogo_lugar WHERE nome = 'Feira Hippie da Afonso Pena';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comida de rua', 3 FROM catalogo_lugar WHERE nome = 'Feira Hippie da Afonso Pena';

UPDATE catalogo_lugar SET
  descricao = 'Museu a céu aberto com jardins, galerias e obras contemporâneas.',
  faixa_preco = 'R$ 50–100',
  avaliacao_media = 4.9,
  avaliacao_total = 5000
WHERE nome = 'Inhotim';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Arte contemporânea', 1 FROM catalogo_lugar WHERE nome = 'Inhotim';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 2 FROM catalogo_lugar WHERE nome = 'Inhotim';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Galerias', 3 FROM catalogo_lugar WHERE nome = 'Inhotim';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Piquenique', 4 FROM catalogo_lugar WHERE nome = 'Inhotim';

UPDATE catalogo_lugar SET
  descricao = 'Praça central de Nova Lima, com jardins e comércio ao redor.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.3,
  avaliacao_total = 180
WHERE nome = 'Praça Bernardino de Lima';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 1 FROM catalogo_lugar WHERE nome = 'Praça Bernardino de Lima';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comércio', 2 FROM catalogo_lugar WHERE nome = 'Praça Bernardino de Lima';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Caminhada', 3 FROM catalogo_lugar WHERE nome = 'Praça Bernardino de Lima';

UPDATE catalogo_lugar SET
  descricao = 'Praça central de Contagem, ponto de encontro e eventos locais.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.2,
  avaliacao_total = 220
WHERE nome = 'Praça Tancredo Neves';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Eventos', 1 FROM catalogo_lugar WHERE nome = 'Praça Tancredo Neves';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comércio', 2 FROM catalogo_lugar WHERE nome = 'Praça Tancredo Neves';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Caminhada', 3 FROM catalogo_lugar WHERE nome = 'Praça Tancredo Neves';

UPDATE catalogo_lugar SET
  descricao = 'Shopping em Betim com lojas, cinema e praça de alimentação.',
  faixa_preco = 'R$ 25–120',
  avaliacao_media = 4.4,
  avaliacao_total = 700
WHERE nome = 'Monte Carmo Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lojas', 1 FROM catalogo_lugar WHERE nome = 'Monte Carmo Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Cinema', 2 FROM catalogo_lugar WHERE nome = 'Monte Carmo Shopping';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Alimentação', 3 FROM catalogo_lugar WHERE nome = 'Monte Carmo Shopping';

UPDATE catalogo_lugar SET
  descricao = 'Lagoa com orla para caminhada, pedal e contemplação.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.5,
  avaliacao_total = 500
WHERE nome = 'Lagoa Central de Lagoa Santa';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Caminhada', 1 FROM catalogo_lugar WHERE nome = 'Lagoa Central de Lagoa Santa';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Pedal', 2 FROM catalogo_lugar WHERE nome = 'Lagoa Central de Lagoa Santa';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Pôr do sol', 3 FROM catalogo_lugar WHERE nome = 'Lagoa Central de Lagoa Santa';

UPDATE catalogo_lugar SET
  descricao = 'Gruta com formações rochosas e visita guiada em Lagoa Santa.',
  faixa_preco = 'R$ 20–40',
  avaliacao_media = 4.6,
  avaliacao_total = 900
WHERE nome = 'Gruta da Lapinha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Visita guiada', 1 FROM catalogo_lugar WHERE nome = 'Gruta da Lapinha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Formações rochosas', 2 FROM catalogo_lugar WHERE nome = 'Gruta da Lapinha';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Trilha', 3 FROM catalogo_lugar WHERE nome = 'Gruta da Lapinha';

UPDATE catalogo_lugar SET
  descricao = 'Praça histórica de Sabará, cercada por casarões coloniais.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.5,
  avaliacao_total = 350
WHERE nome = 'Praça Getúlio Vargas';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Casarões', 1 FROM catalogo_lugar WHERE nome = 'Praça Getúlio Vargas';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'História', 2 FROM catalogo_lugar WHERE nome = 'Praça Getúlio Vargas';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Artesanato', 3 FROM catalogo_lugar WHERE nome = 'Praça Getúlio Vargas';

UPDATE catalogo_lugar SET
  descricao = 'Praça central de Vespasiano, com igreja e comércio local.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.2,
  avaliacao_total = 150
WHERE nome = 'Praça da Matriz';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Igreja', 1 FROM catalogo_lugar WHERE nome = 'Praça da Matriz';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comércio', 2 FROM catalogo_lugar WHERE nome = 'Praça da Matriz';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Eventos', 3 FROM catalogo_lugar WHERE nome = 'Praça da Matriz';

UPDATE catalogo_lugar SET
  descricao = 'Praça de convivência com feiras e eventos da cidade.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.1,
  avaliacao_total = 120
WHERE nome = 'Praça Central de Ribeirão das Neves';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Feiras', 1 FROM catalogo_lugar WHERE nome = 'Praça Central de Ribeirão das Neves';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Eventos', 2 FROM catalogo_lugar WHERE nome = 'Praça Central de Ribeirão das Neves';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Convivência', 3 FROM catalogo_lugar WHERE nome = 'Praça Central de Ribeirão das Neves';

UPDATE catalogo_lugar SET
  descricao = 'Área verde com trilhas, lago e espaços para piquenique.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.4,
  avaliacao_total = 300
WHERE nome = 'Parque Ecológico de Ibirité';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Trilhas', 1 FROM catalogo_lugar WHERE nome = 'Parque Ecológico de Ibirité';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Lago', 2 FROM catalogo_lugar WHERE nome = 'Parque Ecológico de Ibirité';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Piquenique', 3 FROM catalogo_lugar WHERE nome = 'Parque Ecológico de Ibirité';

UPDATE catalogo_lugar SET
  descricao = 'Praça central de Santa Luzia, com jardins e comércio próximo.',
  faixa_preco = 'Grátis',
  avaliacao_media = 4.2,
  avaliacao_total = 140
WHERE nome = 'Praça Afonso Pena';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Jardins', 1 FROM catalogo_lugar WHERE nome = 'Praça Afonso Pena';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Comércio', 2 FROM catalogo_lugar WHERE nome = 'Praça Afonso Pena';
INSERT INTO catalogo_lugar_item (lugar_id, nome, ordem)
SELECT id, 'Caminhada', 3 FROM catalogo_lugar WHERE nome = 'Praça Afonso Pena';

INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 5, 'Vá com fome: as bancas de comida mineira são o destaque.' FROM catalogo_lugar WHERE nome = 'Mercado Central de Belo Horizonte';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 5, 'Ótimo para caminhar e emendar a visita aos museus.' FROM catalogo_lugar WHERE nome = 'Praça da Liberdade';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 5, 'O pôr do sol visto da orla é imperdível.' FROM catalogo_lugar WHERE nome = 'Lagoa da Pampulha';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 5, 'Reserve o dia inteiro, o espaço é enorme e vale cada minuto.' FROM catalogo_lugar WHERE nome = 'Inhotim';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 4, 'Café simples, forte e com atendimento de bairro.' FROM catalogo_lugar WHERE nome = 'Café Palhares';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 5, 'Peça o frango com quiabo e reserve mesa no fim de semana.' FROM catalogo_lugar WHERE nome = 'Restaurante Xapuri';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 4, 'O tour pelo estádio agrada até quem não é fanático por futebol.' FROM catalogo_lugar WHERE nome = 'Mineirão';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 5, 'Confira a programação antes, sempre tem algo bom em cartaz.' FROM catalogo_lugar WHERE nome = 'Palácio das Artes';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 4, 'Vá cedo para aproveitar as barracas de comida e artesanato.' FROM catalogo_lugar WHERE nome = 'Feira Hippie da Afonso Pena';
INSERT INTO catalogo_lugar_avaliacao (lugar_id, usuario_id, autor_nome, nota, comentario)
SELECT id, NULL, 'Curadoria PlaceZ', 4, 'Leve tênis, a visita tem escadas e piso irregular.' FROM catalogo_lugar WHERE nome = 'Gruta da Lapinha';

COMMIT;
