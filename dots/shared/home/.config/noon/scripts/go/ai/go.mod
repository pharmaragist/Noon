module harness

go 1.18

require github.com/mattn/go-sqlite3 v1.14.22

require weather_service v0.0.0

replace weather_service => ../
