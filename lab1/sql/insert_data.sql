INSERT INTO f1.tracks (id, name, country) VALUES
                                              (1, 'Bahrain International Circuit', 'Bahrain'),
                                              (2, 'Suzuka Circuit', 'Japan');

INSERT INTO f1.seasons (id, year, is_active)
VALUES (1, 2024, TRUE);

INSERT INTO f1.grand_prix (id, season_id, track_id, name, round_number)
VALUES
    (1, 1, 1, 'Bahrain Grand Prix', 1),
    (2, 1, 2, 'Japanese Grand Prix', 2);

INSERT INTO f1.sessions (id, grand_prix_id, session_type, session_datetime)
VALUES
    (1, 1, 'RACE', '2025-10-29T15:56:07.024Z'),
    (2, 2, 'RACE', '2025-04-06T12:00:00Z');
