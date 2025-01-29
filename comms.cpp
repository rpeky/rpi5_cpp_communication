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

//to do
//create base json file
//read old json state
//update json state
//broadcast new state

const std::string COMMS_FILE = "dronecomms.json";

//create base json file
void create_jsonfile(){
	json msg = {
		{"test_int",123},
		{"test_str","abcdef"},
		{"test_bool",true},
		{"test_vec",{1,2,3,4,5}}
	};
	std::ofstream file(COMMS_FILE);
	if(file.is_open()){
		file<<msg.dump(4);
		file.close();
		std::cout<<"Json file created: "<<COMMS_FILE<<std::endl;
	}
	else{
		std::cerr<<"Failed to open file for writing"<<std::endl;
	}
}

//read old data
json read_json_comms(){
	std::ifstream file(COMMS_FILE);
	json message;
	if (file.is_open()){
		file>>message;
		file.close();
		std::cout<<"Reading json from file"<<message.dump(4)<<std::endl;
	}
	else{
		std::cerr<<"Failed to open file"<<std::endl;
	}
	return message;
}



void parse_json(){

}

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
		//std::string message = get_curr_time();
		//send json as a string, to parse the json str in the receiver
		json tosend = read_json_comms();
		std::string message = tosend.dump();
		if(sendto(sock, message.c_str(),message.size(),0,(struct sockaddr*)&broadcast_addr,sizeof(broadcast_addr))<0){
			perror("Failed to send message");
		}
		else{
			std::cout<<"Sent: "<<message<<std::endl;
		}
		sleep(2);
	}
	close(sock);
}

int main(){
	create_jsonfile();
	read_json_comms();

	std::string broadcast_ip = "172.16.1.10";

	std::thread sender(udp_send,broadcast_ip);
	//std::thread receiver(udp_receive);

	sender.join();
	//receiver.join();

	return 0;
}
