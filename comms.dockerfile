FROM gcc:latest

RUN apt-get update && apt-get install -y libpthread-stubs0-dev

WORKDIR /app

COPY comms.cpp .

RUN g++ -std=c++17 -o comms comms.cpp -lpthread

CMD ["./comms"]
