import { PortfolioNavbar } from "@/components/PortfolioNavbar"
import { MarketplaceSection } from "@/components/MarketplaceSection"
import { Footer } from "@/components/Footer"

export default function MarketplacePage() {
  return (
    <>
      <PortfolioNavbar />
      <div className="pt-20">
        <MarketplaceSection />
      </div>
      <Footer />
    </>
  )
}