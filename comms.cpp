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

//void parse_json(){
//}

// get current time as a str
std::string get_curr_time(){
	auto now = std::chrono::system_clock::now();
	std::time_t current_time = std::chrono::system_clock::to_time_t(now);
	char time_str[BUFFER_SIZE];
	std::strftime(time_str, sizeof(time_str),"%Y-%m-%d %H:%M:%S", std::localtime(&current_time));
	return std::string(time_str);
}

void udp_send(const std::string &broadcast_ip){
	int sock;
	struct sockaddr_in broadcast_addr;

	// create a udp socket
	if ((sock = socket(AF_INET, SOCK_DGRAM, 0))<0){
		perror("Socket creation fialed");
		return;
	}

	// enable broadcast
	int broadcast_enable = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast_enable, sizeof(broadcast_enable)) < 0){
		perror("Error enabling broadcast");
		close(sock);
		return ;
	}

	// configure broadcast addr
	memset(&broadcast_addr, 0, sizeof(broadcast_addr));
	broadcast_addr.sin_family = AF_INET;
	broadcast_addr.sin_port = htons(PORT);
	broadcast_addr.sin_addr.s_addr = inet_addr(broadcast_ip.c_str());

	while (true){
		std::string message = get_curr_time();
		if(sendto(sock, message.c_str(),message.size(),0,(struct sockaddr*)&broadcast_addr,sizeof(broadcast_addr))<0){
			perror("Failed to send message");
		}
		else{
			std::cout<<"Sent: "<<message<<std::endl;
		}
		sleep(1.5);
	}
	close(sock);
}

int main(){
	std::string broadcast_ip = "172.16.1.10";

	std::thread sender(udp_send,broadcast_ip);
	//std::thread receiver(udp_receive);

	sender.join();
	//receiver.join();

	return 0;
}
