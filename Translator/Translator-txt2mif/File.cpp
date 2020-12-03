#include "File.h"

File::File(const std::string InputFile, const std::string OutputFile)
	: m_InputFile(InputFile), m_OutputFile(OutputFile)
{

}

bool File::convert(int width, int depth) const
{
	std::ifstream instream(m_InputFile);
	if (!instream.good())
		return false;
	std::ofstream outstream(m_OutputFile, std::ios::trunc);
	if (!outstream.good())
		return false;

	// Initialization: mif header
	outstream << "WIDTH=" << width << ";\n";
	outstream << "DEPTH=" << depth << ";\n";
	outstream << "ADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n";

	std::string value;
	char address[10];
	int i_line = 0;

	while (std::getline(instream, value))
	{
		sprintf(address, "%06X", i_line++);
		outstream << address << " : " << value << " ;\n";
	}

	outstream << "END;\n";

	return true;
}
