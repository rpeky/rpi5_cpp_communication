FROM gcc:latest

RUN apt-get update && apt-get install -y libpthread-stubs0-dev

WORKDIR /app

COPY reciever.cpp .

RUN g++ -std=c++17 -o recv reciever.cpp -lpthread

CMD ["./recv"]
