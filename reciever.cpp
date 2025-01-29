#include <iostream>
#include <string>
#include <thread>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>

// remove later, using chrono to send test message for time
#include <chrono>
#include <ctime>

//#include <nlohmann/json.hpp>

//using json = nlohmann::json;

const int PORT = 54321;
const int BUFFER_SIZE=1024;

void udp_receive(){
	int sock;
	struct sockaddr_in recv_addr;
	char buffer[BUFFER_SIZE];

	// create a udp socket
	if ((sock = socket(AF_INET, SOCK_DGRAM, 0))<0){
		perror("Socket creation fialed");
		return;
	}

	// configure receiving addr
	memset(&recv_addr, 0, sizeof(recv_addr));
	recv_addr.sin_family = AF_INET;
	recv_addr.sin_port = htons(PORT);
	recv_addr.sin_addr.s_addr = INADDR_ANY;

	//bind socket to addr
	if(bind(sock,(struct sockaddr*)&recv_addr,sizeof(recv_addr))<0){
		perror("Bind failed");
		close(sock);
		return;
	}

	while (true){
		struct sockaddr_in sender_addr;
		socklen_t addr_len = sizeof(sender_addr);
		ssize_t len = recvfrom(sock,buffer,BUFFER_SIZE-1,0,(struct sockaddr*)&sender_addr,&addr_len);
		if(len>0){
			// terminate the received data
			buffer[len]='\0';
			std::string message(buffer);
			std::cout<<"Received: "<<message<<" from "<<inet_ntoa(sender_addr.sin_addr)<<":"<<ntohs(sender_addr.sin_port) << std::endl;
		}
	}
	close(sock);
}

int main(){
	int sock;
	struct sockaddr_in recv_addr;
	char buffer[BUFFER_SIZE];

	// create a udp socket
	if ((sock = socket(AF_INET, SOCK_DGRAM, 0))<0){
		perror("Socket creation fialed");
		return;
	}

	// configure receiving addr
	memset(&recv_addr, 0, sizeof(recv_addr));
	recv_addr.sin_family = AF_INET;
	recv_addr.sin_port = htons(PORT);
	recv_addr.sin_addr.s_addr = INADDR_ANY;

	//bind socket to addr
	if(bind(sock,(struct sockaddr*)&recv_addr,sizeof(recv_addr))<0){
		perror("Bind failed");
		close(sock);
		return;
	}

	while (true){
		struct sockaddr_in sender_addr;
		socklen_t addr_len = sizeof(sender_addr);
		ssize_t len = recvfrom(sock,buffer,BUFFER_SIZE-1,0,(struct sockaddr*)&sender_addr,&addr_len);
		if(len>0){
			// terminate the received data
			buffer[len]='\0';
			std::string message(buffer);
			std::cout<<"Received: "<<message<<" from "<<inet_ntoa(sender_addr.sin_addr)<<":"<<ntohs(sender_addr.sin_port) << std::endl;
		}
	}
	close(sock);
}
