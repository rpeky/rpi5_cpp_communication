#include <iostream>
#include <string>
#include <thread>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>
#include <fstream>

// remove later, using chrono to send test message for time
#include <chrono>
#include <ctime>

#include <nlohmann/json.hpp>

using json = nlohmann::json;

const int PORT = 54321;
const int BUFFER_SIZE=1024;

const std::string jsonread="dronecomms.json";

int main(){
	int sock;
	struct sockaddr_in recv_addr, sender_addr;
	char buffer[BUFFER_SIZE];

	// create a udp socket
	if ((sock = socket(AF_INET, SOCK_DGRAM, 0))<0){
		perror("Socket creation fialed");
		return -1;
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
		return -1;
	}

	std::cout<<"Listening for UDP json str on port: "<<PORT<<std::endl;

	while (true){
		socklen_t addr_len = sizeof(sender_addr);
		ssize_t len = recvfrom(sock,buffer,BUFFER_SIZE-1,0,(struct sockaddr*)&sender_addr,&addr_len);
		if(len>0){
			// terminate the received data
			buffer[len]='\0';
			std::string json_str(buffer);

			try{
				//parse json
				json recievedjson = json::parse(json_str);

				//do comparison todo


				//save new state
				std::ofstream file(jsonread);
				if(file.is_open()){
					//modify this later for the new message
					file<<recievedjson.dump(4)	;
					file.close();
					std::cout<<"json saved to: "<<jsonread<<std::endl;
				}
				else{
					std::cerr<<"Failed to open file for writing."<<std::endl;
				}

				//debug
				std::cout << "Received JSON from " << inet_ntoa(sender_addr.sin_addr) << ":\n";
				std::cout << recievedjson.dump(4) << std::endl;
				std::cout << "---------------------------------------\n";
			}
			catch(json::exception& e){
				std::cerr << "JSON parsing error: " << e.what() << std::endl;
			}
		}
		close(sock);
		return 0;
	}
}
