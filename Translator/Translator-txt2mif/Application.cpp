#include "File.h"

int main(void)
{
	std::string ifile, ofile;
	std::cout << "Please input the txt(input) file path: \n";
	std::cin >> ifile;
	std::cout << "Please input the mif(output) file path: \n";
	std::cin >> ofile;
	File file(ifile, ofile);
	int width, depth;
	std::cout << "Please input the width and then depth: \n";
	std::cin >> width >> depth;
	if (file.convert(width, depth))
	{
		std::cout << "Successfully converted.\n";
	}
	else {
		std::cout << "Failed.\n";
	}
	return 0;
}